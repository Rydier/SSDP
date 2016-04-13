"
I listen to changes in available resources that provide services, using the SSDP protocol.

An SSDP client can be used to send a single type of message; used to discover available resources when first starting up, or getting an up to date list of the available resources, if resources it cares about, has exceeded the max cache period, without receiving a notification that service is still avaiable.
There are three events that need handling; 
- Resource discovered.
- Resource available/changed.
- Resource about to be unavailable.

As a resource's USN will always identify it uniquely,  we only provide the user two callbacks; one for handling added/changed/discovered resources , and one for handling resource removals.

The client itself does not implement caching of any type, just the raw messaging parts.


Sample usage:
|client|
client := SSDPClient v4SiteLocal.
client filter: 'ssdp:all' 
	availableHandler: [ :resource | resource printOn: Transcript.
		'is available' logCr. ]
	unavailableHandler: [ :resource | resource printOn: Transcript.
		'is becoming unavailable' logCr. ].
	
"
Class {
	#name : #SSDPClient,
	#superclass : #Object,
	#instVars : [
		'socket',
		'availableHandler',
		'unavailableHandler',
		'receiveWindow',
		'discoveryProcess',
		'listenerProcess'
	],
	#category : #SSDP
}

{ #category : #'as yet unclassified' }
SSDPClient class >> v4SiteLocal [
	^self new initializev4SiteLocal
]

{ #category : #'as yet unclassified' }
SSDPClient class >> v6Global [
	^self new initializev6Global
]

{ #category : #'as yet unclassified' }
SSDPClient class >> v6LinkLocal [
	^self new initializev6LinkLocal
]

{ #category : #'as yet unclassified' }
SSDPClient class >> v6OrganizationLocal [
	^self new initializev6OrganizationLocal
]

{ #category : #'as yet unclassified' }
SSDPClient class >> v6SiteLocal [
	^self new initializev6SiteLocal
]

{ #category : #'private - requests' }
SSDPClient >> discoveryRequest: searchTarget receivingAnswersIn: receiveWindowSeconds [
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

{ #category : #setup }
SSDPClient >> filter: aSearchTarget handler: aResourceHandler [
	discoveryProcess ifNotNil: [ discoveryProcess terminate ].
	listenerProcess ifNotNil: [ listenerProcess terminate ].
	handler := aResourceHandler.
	discoveryProcess := self newDiscoveryProcessFor: aSearchTarget.
	listenerProcess := self newListenerProcessFor: aSearchTarget.
	listenerProcess resume.
	discoveryProcess resume.
]

{ #category : #'initialize - release' }
SSDPClient >> initialize [
	"By default, receive all responses in less than a second. Increasing this will spread out processing of responses, as each service will delay for (0 to: receiveWindow) atRandom before responding"
	receiveWindow := 1.
]

{ #category : #'initialize - release' }
SSDPClient >> initializev4SiteLocal [
"Set up a socket to listen/send search requests on the IPv4 site local multicast address 239.255.255.250"

	socket := Socket newUDP setPeer: #[239 255 255 250] port:  self ipv4Port 
]

{ #category : #'initialize - release' }
SSDPClient >> initializev6Global [
	"Set up a socket to listen/send search requests on the IPv6 global multicast address [FF0E::C]"
	^self notYetImplemented 
]

{ #category : #'initialize - release' }
SSDPClient >> initializev6LinkLocal [
"Set up a socket to listen/send search requests on the IPv6 link local multicast address [FF02::C]"
	^self notYetImplemented 
]

{ #category : #'initialize - release' }
SSDPClient >> initializev6OrganizationLocal [
"Set up a socket to listen/send search requests on the IPv6 organization local multicast address [FF08::C]"
	^self notYetImplemented 
]

{ #category : #'initialize - release' }
SSDPClient >> initializev6SiteLocal [
"Set up a socket to listen/send search requests on the IPv6 site local multicast address [FF05::C]"
	^self notYetImplemented 
]

{ #category : #private }
SSDPClient >> ipv4Port [
	^1900
]

{ #category : #private }
SSDPClient >> ipv6LegacyPort [
	"XP > "
	^5000
]

{ #category : #private }
SSDPClient >> ipv6Port [
	^2869
]

{ #category : #setup }
SSDPClient >> newDiscoveryProcessFor: searchTarget [
	^ [ | datagram |

	datagram := self
		discoveryRequest: searchTarget
		receivingAnswersIn: receiveWindow.
	socket
		sendUDPData: datagram
		toHost: socket remoteAddress
		port: socket remotePort ] newProcess
		priority: Processor userBackgroundPriority;
		yourself
]

{ #category : #setup }
SSDPClient >> newListenerProcessFor: aSearchTarget [
	^ [ | status read buffer fullDatagram |
	fullDatagram := buffer := String new: 1024.
	[ socket waitForData.
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
	handler
		value: (SSDPResource readFrom: fullDatagram size: read) ]
		repeat ] newProcess
		priority: Processor userBackgroundPriority;
		yourself
]

{ #category : #accessing }
SSDPClient >> receiveWindow: aNumberOfSeconds [
	receiveWindow := aNumberOfSeconds
]
