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
	offerServiceType: 'ssdp:testService'
	atLocation: 'http:/test.local/'.
server shutDown.
"
Class {
	#name : #SSDPServer,
	#superclass : #SSDPParticipant,
	#instVars : [
		'service',
		'delayGenerator',
		'discoveryProcesses',
		'keepAliveProcesses'
	],
	#category : #'SSDP-Server'
}

{ #category : #'private - available' }
SSDPServer >> aliveAnnouncingProcessOn: aSendingSocket [
	"Keep telling the client our service is available until we are not, and the thread is terminated."

	^ [ [ [ [ aSendingSocket
		sendUDPData: (service aliveResponseFor: aSendingSocket)
		toHost: multicastInfo host
		port: multicastInfo port.
	(service maxAge // 3) wait ] repeat ]
		on: PrimitiveFailed
		do: [ self shutDown ]
	"If we failed, it means my interface is no longer valid"
	"Could rescan available interfaces, but for now, just restart server by triggering termination" ]
		ensure:
			[ [ aSendingSocket
				sendUDPData: (service byebyeResponseFor: aSendingSocket)
				toHost: multicastInfo host
				port: multicastInfo port ]
				on: PrimitiveFailed
				do:
					[ [ self offerService: service ] fork ]	"Termination triggered due to unavailability; fork of a restart" ] ]
		newProcess name: 'SSDP<server:', service serviceType,'> keepalive process'
]

{ #category : #'private - discovery' }
SSDPServer >> discoveryListeningProcessOn: aSocket [
	^ [ | buffer datagram |
	buffer := ByteArray new: 1024.
	[ aSocket waitForData.
	datagram := self readDatagramFrom: aSocket using: buffer.
	(self discoveryRequestFrom: datagram)
		ifNotNil: [ :request | self handleDiscoveryRequest: request receivedOn: aSocket ] ]
		repeat ] newProcess name: 'SSDP<server:', service serviceType,'> discovery listener'
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
SSDPServer >> offerService: anSSDPService [
	self shutDown.
	service := anSSDPService.
	service serverInfo: self versionInfo.
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

{ #category : #'initialize - release' }
SSDPServer >> shutDown [
	service ifNotNil: [ 
		discoveryProcesses do: #terminate.
		keepAliveProcesses do: #terminate.]
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
