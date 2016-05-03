Class {
	#name : #ValueLink,
	#superclass : #Link,
	#instVars : [
		'value'
	],
	#category : #'SSDP-Squeak'
}

{ #category : #'instance creation' }
ValueLink class >> value: aValue [
	^self new value: aValue
]

{ #category : #accessing }
ValueLink >> value [
	^value
]

{ #category : #accessing }
ValueLink >> value: aValue [
	value := aValue
]
