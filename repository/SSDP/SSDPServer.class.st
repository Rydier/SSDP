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
		'serverProcess',
		'aliveProcess'
	],
	#category : #SSDP
}

{ #category : #'private - responses' }
SSDPServer >> aliveResponse: serviceType [
	"The ping we send periodically to notify clients we are still here"
	
	[String crlf join: #('NOTIFY * HTTP/1.1'
   'Host: 239.255.255.250:reservedSSDPport'
   'NT: blenderassociation:blender'
   'NTS: ssdp:alive'
   'USN: someunique:idscheme3'
   'AL: <blender:ixl><http://foo/bar>'
   'Cache-Control: max-age = 7393'
	'') .].
	^('NOTIFY * HTTP/1.1
   Host: 239.255.255.250:reservedSSDPport
   NT: ', serviceType ,'
   NTS: ssdp:alive
   USN: ', serviceType , ':' , self uuid,'
   Cache-Control: max-age = ', self cacheTime asSeconds printString,'
') withInternetLineEndings
]

{ #category : #'private - responses' }
SSDPServer >> byebyeResponse: serviceType [
	"The ping we send when shutting down to notify clients we can no longer provide services"
	
	[String crlf join: #('NOTIFY * HTTP/1.1'
   'Host: 239.255.255.250:reservedSSDPport'
   'NT: blenderassociation:blender'
   'NTS: ssdp:byebye'
   'USN: someunique:idscheme3'
   '') .].
	^('NOTIFY * HTTP/1.1
   Host: 239.255.255.250:reservedSSDPport
   NT: ', serviceType ,'
   NTS: ssdp:byebye
   USN: ', serviceType , ':' , self uuid,'
') withInternetLineEndings
]

{ #category : #accessing }
SSDPServer >> cacheTime [
	^self notYetImplemented 
]

{ #category : #'private - responses' }
SSDPServer >> discoveryResponse: serviceType [
	"The response we send when receiving queries for which services we are  able to provide"

	[String crlf join: #('HTTP/1.1 200 OK'
   'S: someunique:idscheme3'
	'ST: serviceType:id'
   'USN: someunique:idscheme3'
	'Server: urlToService'
	'Cache-Control: max-age = 5000'
   '') .].
	^('HTTP/1.1 200 OK
   ST: ', serviceType ,'
   USN: ', serviceType , ':' , self uuid,'
	Server: ', self serviceLocation, '
	Cache-Control: max-age = ', self cacheTime asSeconds printString,'
') withInternetLineEndings
]

{ #category : #'initialize - release' }
SSDPServer >> service: aServiceIdentifier availableAt: aURI [
	service := SSDPService type: aServiceIdentifier location: aURI.
	serverProcess := self
		newDiscoveryListenerProcessFor: service.
	aliveProcess := self newKeepAliveProcessFor: service.
	
]

{ #category : #accessing }
SSDPServer >> serviceLocation [
	^self notYetImplemented 
]
