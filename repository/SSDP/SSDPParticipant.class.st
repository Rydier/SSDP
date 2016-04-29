"
An SSDPParticipant  is an abstract superclass of entities that needs to communicate using the SSDP protocol.

It implements setup of SSDP sockets, one for each local interface, which will: 
- Receive packets sent to the multicast socket
- Send data to the multicast address

"
Class {
	#name : #SSDPParticipant,
	#superclass : #Object,
	#instVars : [
		'listeningSockets',
		'sendingSockets'
	],
	#category : #'SSDP-Core'
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

	listeningSockets := OrderedCollection new.
	sendingSockets := OrderedCollection new.
	self localV4Addresses
		do:
			[ :IPv4InterfaceAddress | 
			| listeningSocket sendingSocket |
			listeningSocket := Socket newUDP.
			listeningSocket setOption: 'SO_REUSEADDR' value: true.
			listeningSocket bindTo: IPv4InterfaceAddress port: 0.
			"We want this socket to be used to listen to datagrams sent to the SSDP multicast address and port; 
			We need to tell the OS we are interested in packets that arrive at our local interface."
			listeningSocket
				setOption: 'IP_ADD_MEMBERSHIP'
				value: #[239 255 255 250] , IPv4InterfaceAddress.
			listeningSockets add: listeningSocket.
			sendingSocket := Socket newUDP.
			"We want to send data to the SSDP broadcast address"
			sendingSocket setPeer: #[239 255 255 250] port: self ipv4Port.
			sendingSockets add: sendingSocket ]
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

{ #category : #'private - interface enumeration' }
SSDPParticipant >> localAddresses: aFamily port: aPort [
	"Pharo has removed all support classes and calls to the ipv6-aware primitives, 
	amongst them the ones needed to find local interfaces.
	Inline their use here, so it works for both Pharo and Squeak
	Remember to set UseOldNetwork to false when running on Squeak, or localHostname is likely to return
	a helpful result such as '127.0.0.1' instead of the actual hostname"

	"aFamily:
	1 = ipv6
	2 = ipv4"

	| ipOffsets protocol type host result |
	"ipv4 address found from 13-16 in address object, ipv6 from 15-32 "
	ipOffsets := #(#[ 15 32 ] #[ 13 16 ]).
	"Protocol:
	1 = TCP
	2 = UDP
	Type:
	1 = Streaming
	2 = Datagram"
	protocol := 2.
	type := protocol.
	"Obviously, we can't just pass in '' to mean all local addresses, that either resolves to the 'let OS decide' or loopback address depending on flags... So we need to jump some hoops to get the actual network interfaces based on localHostName."
	"Remember to set UseOldNetworking to false when running on Squeak, otherwise localHostName is likely to return a helpful '127.0.0.1' or similar"
	host := NetNameResolver localHostName.
	"If we do not search the .local domain, only first interface that can resolve hostname will be returned, not all"
	host := (host copyUpToLast: $.) , '.local'.
	NetNameResolver initializeNetwork.
	NetNameResolver
		primGetAddressInfoHost: host
		service: aPort asString
		flags: 0
		family: 2
		type: type
		protocol: protocol.	"Obviously, the port number must be passed to primitive as string, lest the primitive crash"	"IPv4"
	result := OrderedCollection new.
	"For now, don't guard the prim call to collect addresses, and the subsequent ones reading the results from outside interference"
	[ | addrSize addr rawAddress |
	addrSize := NetNameResolver primGetAddressInfoSize.
	addrSize < 0
		ifTrue: [ ^ result ].
	addr := ByteArray new: addrSize.
	NetNameResolver primGetAddressInfoResult: addr.
	rawAddress := addr copyFrom: (ipOffsets at: aFamily) first to: (ipOffsets at: aFamily) last.
	NetNameResolver primGetAddressInfoNext.
	result add: rawAddress ] repeat
]

{ #category : #'private - interface enumeration' }
SSDPParticipant >> localV4Addresses [
	"Pharo has removed all support classes and calls to the ipv6-aware primitives, 
	amongst them the ones needed to find local interfaces.
	Inline their use here, so it works for both Pharo and Squeak"
	^self localAddresses: 2 port: self ipv4Port.
]

{ #category : #private }
SSDPParticipant >> readDatagramFrom: aSocket using: buffer [
	| fullDatagram status read |
	"Receiving data will change remoteAddress to the actual sender.
	Senders who care about aSockets values of these are responsible for preserving/restoring them."
	
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
	"We can safely return the fullDatagram without the amount read, since all SSDP messages use http header format, which
	are always terminated with an empty line. So there's no chance for a compliant header parser to mistakenly read past that point"
	^fullDatagram.
	
]
