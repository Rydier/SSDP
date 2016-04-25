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
client := SSDPClient v4SiteLocal.
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
		'availableHandler',
		'unavailableHandler',
		'receiveWindow',
		'discoveryProcess',
		'listenerProcess',
		'cache'
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
		self discover: service serviceType.
		service validDuration < 3 seconds ifTrue: [
		"Nope, we really do have to announce it removed" 
		byebyeHandler value: (cache remove: service) ]
		
		]newProcess
]

{ #category : #private }
SSDPRawClient >> discover: aServiceType [
	"Send an explicit message indicating that services implementing aType should notify me they are available"

	| discoverSocket buffer latestArrivalTime |
	"Use a separate socket to run discovery; this way we don't accidentally receive discovery responses in the regular listener."
	discoverSocket := Socket newUDP.
	discoverSocket
		sendUDPData:
			(self
				discoveryRequest: aServiceType
				receivingAnswersIn: receiveWindow)
		toHost: socket remoteAddress
		port: socket remotePort.
	latestArrivalTime := DateAndTime now asSeconds + receiveWindow.
	buffer := ByteArray new: 1024.
	[ | status read fullDatagram |
	discoverSocket
		waitForDataFor: latestArrivalTime - DateAndTime now asSeconds
		ifTimedOut: [ ^ nil ].
	"TODO: Extract datagram reading, use same method in listener process"
	status := discoverSocket receiveUDPDataInto: buffer.
	read := status at: 1.
	[ (status at: 4)
		and: [ fullDatagram := buffer copyFrom: 1 to: read.
			true ] ]
		whileTrue:
			[ status := discoverSocket receiveUDPDataInto: buffer.
			fullDatagram := fullDatagram
				, (buffer copyFrom: 1 to: (status at: 1)).
			(self updateCache: (SSDPService readFromDiscovery: fullDatagram))
				ifNotNil: [ :service | availableHandler value: service ] ] ]
		repeat
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
	listenerProcess ifNotNil: [ listenerProcess terminate ].
	listenerProcess := self
		newListenerProcessFor: aSearchTarget
		available: aHandler
		unavailable: anotherHandler.
	listenerProcess resume.
	self performDiscovery: aSearchTarget
]

{ #category : #'initialize - release' }
SSDPRawClient >> initialize [
	"By default, receive all responses in less than a second. Increasing this will spread out processing of responses, as each service will delay for (0 to: receiveWindow) atRandom before responding"
	super initialize.
	receiveWindow := 1.
]

{ #category : #processes }
SSDPRawClient >> newListenerProcessFor: aSearchTarget available: whenAvailableOrAlive unavailable: whenByeBye [
	^ [ | status read buffer fullDatagram |
	fullDatagram := buffer := String new: 1024.
	[ |resource| socket waitForData.
	status := socket receiveUDPDataInto: buffer.
	read := status at: 1.
	[ (status at: 4)
		and: [ fullDatagram := buffer copyFrom: 1 to: read.
	true ] ]
		whileTrue:
			[ status := socket receiveUDPDataInto: buffer.
	fullDatagram := fullDatagram
		, (buffer copyFrom: 1 to: (status at: 1)).
	read := read + (status at: 1) ].
	resource := SSDPService readFrom: fullDatagram size: read.
	(self updateCache: resource) ifNotNil: [ 
	resource isAvailable ifTrue: [ 
	whenAvailableOrAlive value: resource]ifFalse: [whenByeBye value: resource ]]. ]
		repeat ] newProcess
		priority: Processor userBackgroundPriority;
		yourself
]

{ #category : #accessing }
SSDPRawClient >> receiveWindow: aNumberOfSeconds [
	receiveWindow := aNumberOfSeconds
]

{ #category : #'private - caching' }
SSDPRawClient >> updateCache: aService [
	"Add if aService isAvailable and not yet in cache, remove if aService isUnavailable and in cache.
	In all other cases, return nil"
	self notYetImplemented
]
