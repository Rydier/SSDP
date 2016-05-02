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
		'cache',
		'listenerProcesses',
		'cachePruningProcess'
	],
	#category : #'SSDP-Client'
}

{ #category : #processes }
SSDPRawClient >> cacheExpulsionProcess: byebyeHandler [
	^[|service|
			[(service := cache first) validDuration.
			service validDuration > 3 seconds] 
				whileTrue: [(service validDuration - 1 second) wait].
		"See if we are able to re-discover the service"
		self discover: service serviceType handleBy: [:aService |].
		service validDuration < 3 seconds ifTrue: [
		"Nope, we really do have to announce it removed" 
		byebyeHandler value: (cache remove: service) ]
		
		]newProcess name: 'SSDP<client:', cache serviceType,'> Cache pruning '
]

{ #category : #private }
SSDPRawClient >> discover: aServiceType handleBy: aHandler [
	"Send an explicit message indicating that services implementing aType should notify me they are available"

	| buffer |
	buffer := ByteArray new: 1024.
	sendingSockets
		do:
			[ : discoverySocket | |remoteAddress remotePort latestArrivalTime| 
			"Reading discovery replies will set remoteAddress/Port to that of the source of the datagram
			So we need to preserve the initial values to be able to run discovery multiple times."
			remoteAddress := discoverySocket remoteAddress.
			remotePort := discoverySocket remotePort.
			discoverySocket
				sendUDPData:
					(self
						discoveryRequest: aServiceType
						receivingAnswersIn: receiveWindow)
				toHost: multicastInfo host
				port: multicastInfo port.
			latestArrivalTime := (DateAndTime now 
				+ receiveWindow asSeconds) .
			
			[ | datagram |
			discoverySocket
				waitForDataForMsecs: (latestArrivalTime - DateAndTime now) asMilliSeconds
				ifClosed: nil
				ifTimedOut: [ ^ nil ].	"Never gonna happen, UDP baby"
			datagram :=  self
				readDatagramFrom: discoverySocket
				using: buffer.
			((SSDPDiscoveryReply fromDatagram: datagram) serviceChangeIn: cache)
				ifNotNil: [ :service | aHandler value: service ] ]
				repeat.
			discoverySocket setPeer: remoteAddress port: remotePort ]
]

{ #category : #'private - requests' }
SSDPRawClient >> discoveryRequest: searchTarget receivingAnswersIn: receiveWindowSeconds [
	"Nothing but headers, and a blank line"
	
	"TODO: Rewrite to use multicastInfo for host" 
	^('M-SEARCH * HTTP/1.1
HOST: 239.255.255.250:1900
MAN: "ssdp:discover"
MX:', receiveWindowSeconds asString, '
ST:', searchTarget, '
') withInternetLineEndings
]

{ #category : #'initialize - release' }
SSDPRawClient >> filter: aSearchTarget whenAvailable: aHandler whenUnavailable: anotherHandler [
	
	cache := SSDPCache for: aSearchTarget.
	listenerProcesses ifNotNil: [ listenerProcesses do: #terminate ].
	self discover: aSearchTarget handleBy: aHandler.
	listenerProcesses := listeningSockets
		collect:
			[ :aSocket | 
			self
				newListenerProcessFor: aSearchTarget
				on: aSocket
				available: aHandler
				unavailable: anotherHandler ].
	listenerProcesses do: #resume.
	cachePruningProcess := self cacheExpulsionProcess: anotherHandler.
	cachePruningProcess resume.

]

{ #category : #'initialize - release' }
SSDPRawClient >> initialize [
	"By default, receive all responses in less than a second. Increasing this will spread out processing of responses, as each service will delay for (0 to: receiveWindow) atRandom before responding"
	super initialize.

	receiveWindow := 1.
	
]

{ #category : #debugging }
SSDPRawClient >> inspectMissing: aDatagram [
	"If missing messages, uncomment halt here to see if we parse it correctly"
	"self halt"
]

{ #category : #processes }
SSDPRawClient >> newListenerProcessFor: aSearchTarget on: aSocket available: whenAvailable unavailable: whenByeBye [
	^ [ | buffer |

	buffer := String new: 1024.
	[ | datagram  |
	aSocket waitForData.
	
	datagram := self readDatagramFrom: aSocket using: buffer.
	(SSDPMessage from: datagram) 
		ifNil: [ 
			self inspectMissing: datagram ]
		ifNotNil: [ :notification |
		(notification serviceChangeIn: cache)
			ifNotNil:
			[ :service | 
			notification deliver: service 
				ifAvailable: whenAvailable
				ifUnavailable: whenByeBye ]] 
				 ] repeat 
	] newProcess
		name: 'SSDP<client:', aSearchTarget, '> change listener';
		priority: Processor userBackgroundPriority;
		yourself
]

{ #category : #accessing }
SSDPRawClient >> receiveWindow: aNumberOfSeconds [
	receiveWindow := aNumberOfSeconds
]
