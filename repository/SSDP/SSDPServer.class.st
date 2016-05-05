"
An SSDPServer know how to announce to clients that there is a service available.
It implements the server-part of SSDP, specifically:
- Responding to M-SEARCH requests to the SSDP multicast address
- Sending ssdp:alive messages to refresh cache-expiry in clients.
- Sending ssdp:byebye messages to explicitly tell clients the service is no longer available

At the moment, for simplicity, there's a 1-1 mapping between server and services; if more should be available, use multiple servers.

Sample usage:
|server|
server := SSDPServer v4SiteLocal.
server 
	service: 'ssdp:testService'
	availableAt: 'http:/test.local/'.
server stop.
"
Class {
	#name : #SSDPServer,
	#superclass : #SSDPParticipant,
	#instVars : [
		'service',
		'delayGenerator',
		'discoveryProcesses',
		'keepAliveProcesses',
		'replySockets'
	],
	#category : #'SSDP-Server'
}

{ #category : #'private - available' }
SSDPServer >> aliveAnnouncingProcessOn: aSendingSocket [
	"Keep telling the client our service is available until we are not, and the thread is terminated."

	^ [ [ [ [ aSendingSocket
		sendUDPData: (service aliveResponseFor: multicastInfo)
		toHost: multicastInfo host
		port: multicastInfo port.
	(service maxAge // 3) wait ] repeat ]
		on: PrimitiveFailed
		do: [ self shutDown ]
	"If we failed, it means my interface is no longer valid"
	"Could rescan available interfaces, but for now, just restart server by triggering termination" ]
		ensure:
			[ [ aSendingSocket
				sendUDPData: (service byebyeResponseFor: multicastInfo)
				toHost: multicastInfo host
				port: multicastInfo port ]
				on: PrimitiveFailed
				do:
					[ [ self offerService: service ] fork ]	"Termination triggered due to unavailability; fork of a restart which will scan currently available interfaces" ] ]
		newProcess name: 'SSDP<server:', service serviceType,'> keepalive process'
]

{ #category : #'private - discovery' }
SSDPServer >> discoveryListeningProcessOn: aListeningSocket [
	^ [ | buffer senderAndDatagram |
	buffer := ByteArray new: 1024.
	[ aListeningSocket waitForData.
	senderAndDatagram := self
		readSenderAndDatagramFrom: aListeningSocket
		using: buffer.
	(self discoveryRequestFrom: senderAndDatagram value)
		ifNotNil:
			[ :request | 
			| replySocket |
			"Reply using the socket bound to same interface as we are listening on"
			replySocket := replySockets
				at: (listeningSockets indexOf: aListeningSocket).
			self
				replyToDiscoveryRequest: request
				from: senderAndDatagram key
				on: replySocket ] ] repeat ] newProcess
		name: 'SSDP<server:' , service serviceType , '> discovery listener'
]

{ #category : #'private - discovery' }
SSDPServer >> discoveryRequestFrom: aDatagram [
	^ (SSDPDiscoveryRequest
		fromDatagram: aDatagram)
		ifNotNil: [ :request | 
				(service matchesType: request)
				ifTrue: [ request ] ]
]

{ #category : #'private - discovery' }
SSDPServer >> handleDiscoveryRequest: request receivedOn: aSocket [
	| destAddress destPort |
	"We fork off delivery, so we need to remember where we can send reply to client"
	destAddress := aSocket remoteAddress.
	destPort := aSocket remotePort.
	"We should send our response at some random time before the discovery interval elapses"
	[ 
		(request timeout * delayGenerator next ) wait.
	aSocket
		sendUDPData: service discoveryResponse
		toHost: destAddress
		port: destPort ] forkAt: Processor activeProcess priority + 1
]

{ #category : #'initialize - release' }
SSDPServer >> initialize [
	super 	initialize.
	delayGenerator := Random new.
]

{ #category : #'initialize - release' }
SSDPServer >> initializeSocketsForInterface: localInterface [
	"Setup sockets that can listen and send data to the multicast address on the subnet of localInterface"

	^ (super initializeSocketsForInterface: localInterface)
		and:
			[ | replySocket |
			replySocket := Socket newUDP.
			replySocket bindTo: localInterface port: 0.
			replySockets add: replySocket.
			 true ]
]

{ #category : #'initialize - release' }
SSDPServer >> initializeSocketsOn: localInterfaces [
	"A server needs sockets not bound to the multicast address when replying to discovery requests"
	replySockets := OrderedCollection new.
	super initializeSocketsOn: localInterfaces
]

{ #category : #starting }
SSDPServer >> offerService: anSSDPService [
	self shutDown.
	service := anSSDPService.
	service serverInfo: self versionInfo.
	self startUp.
]

{ #category : #starting }
SSDPServer >> offerServiceType: aServiceType atLocation: aLocation [
	^ self
		offerService:
			(SSDPService
				ofType: aServiceType
				atLocation: aLocation)
]

{ #category : #'private - discovery' }
SSDPServer >> replyToDiscoveryRequest: request from: aSender on: aReplySocket [

	"We should send our response at some random time before the discovery interval elapses"
	[ 
		(request timeout * delayGenerator next ) wait.
	aReplySocket
		sendUDPData: service discoveryResponse
		toHost: aSender host
		port: aSender port ] forkAt: Processor activeProcess priority + 1
]

{ #category : #'initialize - release' }
SSDPServer >> shutDown [
	service ifNotNil: [ 
		discoveryProcesses do: #terminate.
		keepAliveProcesses do: #terminate.]
]

{ #category : #'initialize - release' }
SSDPServer >> startUp [

	super startUp.
	discoveryProcesses := listeningSockets
		collect: [ :discoverySocket | 
			self discoveryListeningProcessOn: discoverySocket ].
	keepAliveProcesses := sendingSockets 
		collect: [:keepAliveSocket | 
			self aliveAnnouncingProcessOn: keepAliveSocket ].
	discoveryProcesses do: #resume.
	keepAliveProcesses do: #resume.
	
]

{ #category : #accessing }
SSDPServer >> versionInfo [
	"Only pretend we support SSDP draft spec.
	uPnP 1.1 has additional requirements, like BOOTID.UPNP.ORG fields in keep-alive messages"
	| os systemVersion |
	os := Smalltalk os.
	systemVersion := SystemVersion current.
	^ (Smalltalk os platformName reject: [:e | e = Character space]) , '/' , os version , 
	' ssdp/0.9 ' , 
	systemVersion type , '/' , systemVersion dottedMajorMinor
]
