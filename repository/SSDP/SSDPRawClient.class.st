"
An SSDPRawClient listens to changes in available resources that provide services, using the SSDP protocol.

An SSDP client can be used to send a single type of message; used to discover available resources when first starting up, or getting an up to date list of the available resources, if resources it cares about, has exceeded the max cache period, without receiving a notification that service is still avaiable.
There are three SSDP events that need handling; 
- Service discovered.
- Service available/changed.
- Service about to be unavailable.

As a Service's USN will always identify it uniquely,  we hold a cache of the current status of Services (if the events can be cached), and, if an event signifies an addition or removal, pass this info on.

Thus, a user must initialize me with the service type it is interested in and two callbacks.
Sample usage:
|client|
client := SSDPRawClient v4SiteLocal.
client filter: 'ssdp:all' 
	whenAvailable: [ :resource | resource printOn: Transcript.
		'is available' logCr. ]
	whenUnavailable: [ :resource | resource printOn: Transcript.
		'is becoming unavailable' logCr. ].
	
"
Class {
	#name : #SSDPRawClient,
	#superclass : #SSDPParticipant,
	#instVars : [
		'receiveWindow',
		'discoveryProcess',
		'cache',
		'listenerProcesses'
	],
	#category : #SSDP
}

{ #category : #processes }
SSDPRawClient >> cacheExpulsionProcess: byebyeHandler [
	|cacheUpdateProcess|
	cacheUpdateProcess := 
		[|service|
			[(service := cache first) validDuration.
			service validDuration > 3 seconds] 
				whileTrue: [(service validDuration - 1) wait].
		"See if we are able to re-discover the service"
		self discover: service serviceType handleBy: [:aService |].
		service validDuration < 3 seconds ifTrue: [
		"Nope, we really do have to announce it removed" 
		byebyeHandler value: (cache remove: service) ]
		
		]newProcess
]

{ #category : #private }
SSDPRawClient >> discover: aServiceType handleBy: aHandler [
	"Send an explicit message indicating that services implementing aType should notify me they are available"

	| discoverSocket buffer latestArrivalTime |
	"Use a separate socket to run discovery; this way we don't accidentally receive discovery responses in the regular listeners."
	sockets
		do:
			[ :aSocket | |realRemoteAddress|
			discoverSocket := Socket newUDP.
			"somehow, find the local interface that aSocket was setup to listen to multicast announcements from, so we can bind the discoverSocket to send over it here..."
			discoverSocket bindTo: aSocket localAddress port: 0.
			discoverSocket
				sendUDPData:
					(self
						discoveryRequest: aServiceType
						receivingAnswersIn: receiveWindow)
				toHost: aSocket remoteAddress
				port: aSocket remotePort.
			latestArrivalTime := (DateAndTime now 
				+ receiveWindow asSeconds) .
			buffer := ByteArray new: 1024.
			[ | dataAndSize |
			discoverSocket
				waitForDataForMsecs: (latestArrivalTime - DateAndTime now) asMilliSeconds
				ifClosed: nil
				ifTimedOut: [ ^ nil ].	"Never gonna happen, UDP baby"
			"TODO: Extract datagram reading, use same method in listener process"
			dataAndSize := self
				readDatagramFrom: discoverSocket
				using: buffer.
			(self
				updateCache:
					(SSDPService
						readDiscovery: dataAndSize first
						size: dataAndSize last))
				ifNotNil: [ :service | aHandler value: service ] ]
				repeat ]
]

{ #category : #'private - requests' }
SSDPRawClient >> discoveryRequest: searchTarget receivingAnswersIn: receiveWindowSeconds [
	"Nothing but headers, and a blank line"
	
	[String crlf join: #(
   'M-SEARCH * HTTP/1.1'
   'HOST:239.255.255.250:1900'
   'MAN:"ssdp:discover"'
   'MX:1'
   'ST:ssdp:all'
   '')].
	^('M-SEARCH * HTTP/1.1
HOST:239.255.255.250:1900
MAN:"ssdp:discover"
MX:', receiveWindowSeconds asString, '
ST:', searchTarget, '
') withInternetLineEndings
]

{ #category : #'initialize - release' }
SSDPRawClient >> filter: aSearchTarget whenAvailable: aHandler whenUnavailable: anotherHandler [
	listenerProcesses ifNotNil: [ listenerProcesses do: #terminate ].
	self discover: aSearchTarget handleBy: aHandler.
	listenerProcesses := sockets
		collect:
			[ :aSocket | 
			self
				newListenerProcessFor: aSearchTarget
				on: aSocket
				available: aHandler
				unavailable: anotherHandler ].
	listenerProcesses do: #resume.

]

{ #category : #'initialize - release' }
SSDPRawClient >> initialize [
	"By default, receive all responses in less than a second. Increasing this will spread out processing of responses, as each service will delay for (0 to: receiveWindow) atRandom before responding"
	super initialize.
	receiveWindow := 1.
]

{ #category : #processes }
SSDPRawClient >> newListenerProcessFor: aSearchTarget on: aSocket available: whenAvailableOrAlive unavailable: whenByeBye [
	^ [ | buffer |

	buffer := String new: 1024.
	[ | dataAndSize resource |
	aSocket waitForData.
	dataAndSize := self readDatagramFrom: aSocket using: buffer.
	resource := SSDPService readNotify: dataAndSize first size: dataAndSize last.
	(self updateCache: resource)
		ifNotNil:
			[ 
			resource isAvailabilityNotification
				ifTrue: [ whenAvailableOrAlive value: resource ].
			resource isUnavailabilityNotification
				ifTrue: [ whenByeBye value: resource ] 
				] ] repeat 
	] newProcess
		priority: Processor userBackgroundPriority;
		yourself
]

{ #category : #private }
SSDPRawClient >> readDatagramFrom: aSocket using: buffer [
	| fullDatagram status read realAddress realPort|
	"Receiving data will change remoteAddress to the actual sender.
	Make sure we reset to the multicast-address when datagram has been read, so sending messages will work as expected"

	realAddress := aSocket remoteAddress.
	realPort := aSocket remotePort.
	fullDatagram := buffer.
	status := aSocket receiveUDPDataInto: buffer.
	read := status at: 1.
	(status at: 4)
		ifTrue: [ fullDatagram := buffer copyFrom: 1 to: read ].
	[ status at: 4 ]
		whileTrue:
			[ status := aSocket receiveUDPDataInto: buffer.
			read := read + (status at: 1).
			fullDatagram := fullDatagram
				, (buffer copyFrom: 1 to: (status at: 1)) ].
	aSocket setPeer: realAddress port: realPort.
	^ {fullDatagram.
	read}
]

{ #category : #accessing }
SSDPRawClient >> receiveWindow: aNumberOfSeconds [
	receiveWindow := aNumberOfSeconds
]

{ #category : #'private - caching' }
SSDPRawClient >> updateCache: aService [
	"Add if aService isAvailable and not yet in cache, remove if aService isUnavailable and in cache.
	In all other cases, return nil"

	"For testing, assume nothing is cached"

	[ aService isAvailabilityNotification
		ifTrue: [ ^ cache updateLocationOf: aService ].
	aService isUnavailabilityNotification
		ifTrue: [ ^ cache removeService: aService ] ].
	^ aService
]
