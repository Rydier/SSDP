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
		'discoveryProcesses',
		'keepAliveProcesses'
	],
	#category : #'SSDP-Server'
}

{ #category : #'private - available' }
SSDPServer >> aliveAnnouncingProcessOn: aSendingSocket [
	"Keep telling the client our service is available until we are not, and the thread is terminated."
	^ [ [ [ aSendingSocket
		sendUDPData: (service aliveResponseFor: aSendingSocket)
		toHost: aSendingSocket remoteAddress
		port: aSendingSocket remotePort.
	(service maxAge // 3) wait ] repeat ]
		ensure:
			[ aSendingSocket
				sendUDPData: (service byebyeResponseFor: aSendingSocket)
				toHost: aSendingSocket remoteAddress
				port: aSendingSocket remotePort ] ] newProcess name: 'SSDP keepalive process'
]

{ #category : #accessing }
SSDPServer >> cacheTime [
	^self notYetImplemented 
]

{ #category : #'private - discovery' }
SSDPServer >> discoveryListeningProcessOn: aSocket [
	^ [ | buffer datagram |
	buffer := ByteArray new: 1024.
	[ aSocket waitForData.
	datagram := self readDatagramFrom: aSocket using: buffer.
	(self discoveryRequestFrom: datagram)
		ifNotNil: [ :request | self handleDiscoveryRequest: request receivedOn: aSocket ] ]
		repeat ] newProcess name: 'SSDP discovery listener'
]

{ #category : #'private - discovery' }
SSDPServer >> discoveryRequestFrom: aDatagram [
	^ (SSDPDiscoveryRequest
		fromDatagram: aDatagram)
		ifNotNil: [ :request | 
			(request relatedTo: service)
				ifTrue: [ request ] ]
]

{ #category : #'private - discovery' }
SSDPServer >> handleDiscoveryRequest: request receivedOn: aSocket [
	| destAddress destPort |
	"We fork off delivery, so we need to remember where we can send reply to client"
	destAddress := aSocket remoteAddress.
	destPort := aSocket remotePort.
	"We should send our response at some random time before the discovery interval elapses"
	"[ "	self halt. 
		(request timeout * SharedRandom globalGenerator next ) wait.
	aSocket
		sendUDPData: service discoveryResponse
		toHost: destAddress
		port: destPort "] forkAt: Processor activeProcess priority + 1"
]

{ #category : #'initialize - release' }
SSDPServer >> offerService: anSSDPService [
	self stop.
	service := anSSDPService.
	discoveryProcesses := listeningSockets
		collect: [ :discoverySocket | 
			self discoveryListeningProcessOn: discoverySocket ].
	keepAliveProcesses := sendingSockets 
		collect: [:keepAliveSocket | 
			self aliveAnnouncingProcessOn: keepAliveSocket ].
	discoveryProcesses do: #resume.
	keepAliveProcesses do: #resume.
	
]

{ #category : #'initialize - release' }
SSDPServer >> offerServiceType: aServiceType atLocation: aLocation [
	^ self
		offerService:
			(SSDPService
				ofType: aServiceType
				atLocation: aLocation)
]

{ #category : #accessing }
SSDPServer >> serviceLocation [
	^self notYetImplemented 
]

{ #category : #'initialize - release' }
SSDPServer >> stop [
	service ifNotNil: [ 
		discoveryProcesses do: #terminate.
		keepAliveProcesses do: #terminate.]
]
