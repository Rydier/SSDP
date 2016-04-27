Extension { #name : #Socket }

{ #category : #'*SSDP-ipv4 ' }
Socket >> bindTo: anAddress port: aPort [
	^self primSocket: socketHandle bindTo: anAddress port: aPort
]

{ #category : #'*SSDP' }
Socket >> primSocket: socketID bindTo: socketAddress port: aPort [

	<primitive: 'primitiveSocketBindToPort' module: 'SocketPlugin'>
	self primitiveFailed
]
