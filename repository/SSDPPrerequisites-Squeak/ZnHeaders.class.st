Class {
	#name : #ZnHeaders,
	#superclass : #Object,
	#category : #'SSDPPrerequisites-Squeak'
}

{ #category : #'instance creation' }
ZnHeaders class >> initialize [
	"On first load, setup handlers in SSDP that deal with PrimitiveFailed raised by sockets to be handled by SocketPrimitiveFailed on Squeak."
	Smalltalk at: #PrimitiveFailed put: SocketPrimitiveFailed
]

{ #category : #'instance creation' }
ZnHeaders class >> readFrom: aStream [
	^WebUtils readHeadersFrom: aStream
]
