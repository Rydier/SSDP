"
An SSDPParticipant  is an abstract superclass of entities that needs to communicate using the SSDP protocol.

It implements setup of a given SSDP socket, which will: 
- Receive packets sent to the multicast socket
- Send data to the multicast address

"
Class {
	#name : #SSDPParticipant,
	#superclass : #Object,
	#instVars : [
		'socket'
	],
	#category : #SSDP
}

{ #category : #'as yet unclassified' }
SSDPParticipant class >> v4SiteLocal [
	^self new initializev4SiteLocal
]

{ #category : #'as yet unclassified' }
SSDPParticipant class >> v6Global [
	^self new initializev6Global
]

{ #category : #'as yet unclassified' }
SSDPParticipant class >> v6LinkLocal [
	^self new initializev6LinkLocal
]

{ #category : #'as yet unclassified' }
SSDPParticipant class >> v6OrganizationLocal [
	^self new initializev6OrganizationLocal
]

{ #category : #'as yet unclassified' }
SSDPParticipant class >> v6SiteLocal [
	^self new initializev6SiteLocal
]

{ #category : #'initialize - release' }
SSDPParticipant >> initializev4SiteLocal [
"Set up a socket to listen/send search requests on the IPv4 site local multicast address 239.255.255.250"

	(socket := Socket newUDP).
	"We want this socket to be used to listen to datagrams sent to the SSDP multicast address and port"
	socket bindTo: #[239 255 255 250 ] port: self ipv4Port.
	"We need to tell the OS we are interested in packets that arrive at our local interface.
	(Might need something more )"
	socket setOption: 'IP_ADD_MEMBERSHIP' value: #[239 255 255 250 ], NetNameResolver localHostAddress.
	"We want to send data to the SSDP broadcast"
	socket  setPeer: #[239 255 255 250 ]port: self ipv4Port.

]

{ #category : #'initialize - release' }
SSDPParticipant >> initializev6Global [
	"Set up a socket to listen/send search requests on the IPv6 global multicast address [FF0E::C]"
	^self notYetImplemented 
]

{ #category : #'initialize - release' }
SSDPParticipant >> initializev6LinkLocal [
"Set up a socket to listen/send search requests on the IPv6 link local multicast address [FF02::C]"
	^self notYetImplemented 
]

{ #category : #'initialize - release' }
SSDPParticipant >> initializev6OrganizationLocal [
"Set up a socket to listen/send search requests on the IPv6 organization local multicast address [FF08::C]"
	^self notYetImplemented 
]

{ #category : #'initialize - release' }
SSDPParticipant >> initializev6SiteLocal [
"Set up a socket to listen/send search requests on the IPv6 site local multicast address [FF05::C]"
	^self notYetImplemented 
]

{ #category : #private }
SSDPParticipant >> ipv4Port [
	^1900
]

{ #category : #private }
SSDPParticipant >> ipv6LegacyPort [
	"XP > "
	^5000
]

{ #category : #private }
SSDPParticipant >> ipv6Port [
	^2869
]
