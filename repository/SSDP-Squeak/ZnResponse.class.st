Class {
	#name : #ZnResponse,
	#superclass : #WebResponse,
	#category : #'SSDP-Squeak'
}

{ #category : #'instance creation' }
ZnResponse class >> readFrom: aStream [
	^self new readFrom: aStream
]

{ #category : #'as yet unclassified' }
ZnResponse >> headers [
	^headers
]
