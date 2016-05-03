Class {
	#name : #ZnResponse,
	#superclass : #WebResponse,
	#category : #'SSDPPrerequisites-Squeak'
}

{ #category : #'instance creation' }
ZnResponse class >> readFrom: aStream [
	^self new readFrom: aStream
]

{ #category : #'as yet unclassified' }
ZnResponse >> headers [
	"Zn returns Dictionary of normalized keys -> values, not collection of assocs"
	|return|
	return := Dictionary new: headers size.
	headers do: [:each | 
		return at: each key asLowercase capitalized put: each value].
	^return
]
