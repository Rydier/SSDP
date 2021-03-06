"
An SSDPParticipant  is an abstract superclass of entities that needs to communicate using the SSDP protocol.

It implements setup of SSDP sockets, one for each local interface, which will: 
- Receive packets sent to the multicast socket
- Send data to the multicast address

Sending and receiving to the same interface must happen on logically separate sockets, as on some platforms, the interface the socket must be bound to in order to listen to multicast traffic, will mean primitive failures if we try sending over the same socket.

Both listening and sending sockets must have been added to the multicast group;
- listening sockets to receive anything at all 
- sending sockets to not have their traffic discarded by routers and only reach local addresses.

Any attempt to send data to addresses other than the multicast addresses on sockets that have been bound to the multicast group  WILL FAIL, so if a reply should be sent directly to some address, the participant must create the sockets over which these are sent separately.

By default, participants will try to rediscover currently available interfaces, and restart running on these if a PrimitiveError is signalled by a socket. If custom handling is required, participants can be initialized with a special handler block, whose parameters are the participant itself, as well as the socket that error originated on. 

"
Class {
	#name : #SSDPParticipant,
	#superclass : #Object,
	#instVars : [
		'listeningSockets',
		'sendingSockets',
		'multicastInfo',
		'runningOn',
		'socketFailHandler'
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

{ #category : #'private - interface enumeration' }
SSDPParticipant >> allLocalAddressesFor: aMulticastAddress [
	^ aMulticastAddress size = 4
		ifTrue: [ self allLocalV4Addresses ]
		ifFalse: [ self allLocalV6Addresses ]
]

{ #category : #'private - interface enumeration' }
SSDPParticipant >> allLocalV4Addresses [
	"Pharo has removed all support classes and calls to the ipv6-aware primitives, 
	amongst them the ones needed to find local interfaces.
	Inline their use here, so it works for both Pharo and Squeak"
	^self localAddresses: 2 port: self ipv4Port.
]

{ #category : #'private - interface enumeration' }
SSDPParticipant >> allLocalV6Addresses [
	^self notYetImplemented 
]

{ #category : #'private - interface enumeration' }
SSDPParticipant >> defaultLocalV4Addresses [
	"A meta-address used to let the system determine which interface to bind a port on"
	^#(#[0 0 0 0])
]

{ #category : #'private - interface enumeration' }
SSDPParticipant >> defaultLocalV6Addresses [
	"A meta-address used to let the system determine which interface to bind a port on"
	^self notYetImplemented 
]

{ #category : #private }
SSDPParticipant >> hostName [
	|host domainIx|
	"Remember to set UseOldNetworking to false when running on Squeak, otherwise localHostName is likely to return a helpful '127.0.0.1' or similar"
	NetNameResolver initializeNetwork.
	host := NetNameResolver localHostName.
	"Strip out any subdomains, to get the most available interfaces, local if none in name so we do a dns lookup, instead of returning loopback ip"
	"if host is just an ip address do nothing"
	(host copyUpTo: $.) isAllDigits
		ifFalse: [
	Smalltalk os platformName = 'Mac OS' ifFalse: [domainIx := host lastIndexOf: $..
	domainIx > 0 
		ifTrue: [host := (host copyUpTo: $.) ] .
	host := host, '.local'].].
	^host
]

{ #category : #'initialize - release' }
SSDPParticipant >> initializeSocketsForInterface: localInterface [
	"Setup sockets that can listen and send data to the multicast address on the subnet of localInterface"
| listeningSocket sendingSocket validMulticast |
			listeningSocket := Socket newUDP.
			listeningSocket setOption: 'SO_REUSEADDR' value: true.
			"Add to multicast group so the OS doesn't block the traffic we're interested in"
			listeningSocket
				setOption: 'IP_ADD_MEMBERSHIP'
				value: multicastInfo host , localInterface.
			Smalltalk os platformName = 'Win32'
			ifFalse:[ "To receive traffic sent to multicast address, OSX must be bound to the multicast address"
					"Do the same on *nix, not sure if needed, but save the extra branch unless found necessary"
					listeningSocket bindTo: multicastInfo host port: multicastInfo port ] 
				ifTrue: [ "Windows on the other hand, does not allow binding to multicast addresses, but will receive multicast traffic when bound to a local interface. Though, it also must be bound to the correct port"
					listeningSocket bindTo: localInterface port: multicastInfo port ].	

			
				
		"Theoretically, on Windows, there's no technical reason why we could not use the same socket to send, but since in the actual subclasses we use processes waiting on data from sending/listening sockets, with different handlers, it's more convenient to just create separate sockets here for Windows as well."		
			sendingSocket := Socket newUDP.
				"Sending sockets also need to be added to the multicast group, otherwise network interface will only deliver packets we send locally."
			sendingSocket
				setOption: 'IP_ADD_MEMBERSHIP'
				value: multicastInfo host , localInterface.
			"We want to send data from the specific local interface"
			sendingSocket bindTo: localInterface port: 0.
			
		
			"If we can't send data through this interface, exclude it from those we communicate with.
			(For instance, it fails for virtual interfaces created by non-running Parallels VM's on OSX)"
			validMulticast := [ 
				"Probing with an empty package causes listening sockets to end up in ConnectedButClosedByOtherSide, so send a packet with length=1"
				sendingSocket
				sendUDPData: #[0]
				toHost: multicastInfo host
				port: multicastInfo port.
			true ]
				on: PrimitiveFailed
				do: [ false ].
			
			validMulticast
				ifTrue: [ listeningSockets add: listeningSocket.
					sendingSockets add: sendingSocket ].
		^validMulticast

]

{ #category : #'initialize - release' }
SSDPParticipant >> initializeSocketsOn: localInterfaces [
	listeningSockets := OrderedCollection new.
	sendingSockets := OrderedCollection new.
	^localInterfaces
		select:
			[ :localInterfaceAddress | 
			self initializeSocketsForInterface: localInterfaceAddress ]
]

{ #category : #'initialize - release' }
SSDPParticipant >> initializev4SiteLocal [
	"Set up a socket to listen/send search requests on the IPv4 site local multicast address 239.255.255.250"

	multicastInfo := ProtocolClient new host: #[239 255 255 250]; port: 1900; yourself.
	
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
	a helpful result such as '127.0.0.1' instead of the actual hostname.
	Assume distinct hostnames on the network, otherwise, we may return the ip address of another machine with the same name..."

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
	host := self hostName.
	
	NetNameResolver
		primGetAddressInfoHost: host
		service: aPort asString
		flags: 0
		family: aFamily
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
	"Observed duplicate entries when disabling/enabling networks on OSX; remove any such just in case"
	(result includes: rawAddress) ifFalse: [result add: rawAddress] ] repeat
]

{ #category : #'private - interface enumeration' }
SSDPParticipant >> localAddressesFor: aMulticastAddress [
	^ aMulticastAddress size = 4
		ifTrue: [ self defaultLocalV4Addresses ]
		ifFalse: [ self defaultLocalV6Addresses ]
]

{ #category : #accessing }
SSDPParticipant >> multicastInfoPort [
	^multicastInfo port
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

{ #category : #private }
SSDPParticipant >> readSenderAndDatagramFrom: aSocket using: buffer [
	| fullDatagram status read |
	"Use this method to read datagrams for which the sender expects a reply; normally receiveUDPDataInto: sets remoteAddress/port to this info; but not for multicast sockets. Nor is it very thread-safe to fork of replies... "

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
	^(ProtocolClient new host: status second; port: status third; yourself) -> fullDatagram.
	
]

{ #category : #'initialize - release' }
SSDPParticipant >> startUp [
	"Let socket finalization handle release of resources; but ensure sockets are valid when we start up"
	runningOn := 
	self initializeSocketsOn: (self localAddressesFor: multicastInfo host).
	
]

{ #category : #'initialize - release' }
SSDPParticipant >> startUpOnAll [
	"Let socket finalization handle release of resources; but ensure sockets are valid when we start up"
	runningOn := 
	self initializeSocketsOn: (self allLocalAddressesFor: multicastInfo host).
	
]
