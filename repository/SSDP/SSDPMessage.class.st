"
An SSDPMessage  subclass represents a distinct unit of communication between servers and clients, as defined by the protocol.

These objects are only created/used by the receiving end where handling is made easier by having actual objects; the data the messages consist of is simple enough that we construct the serialized representation at the point they are sent.
"
Class {
	#name : #SSDPMessage,
	#superclass : #Object,
	#instVars : [
		'serviceType',
		'uniqueServiceName'
	],
	#category : #'SSDP-Core'
}

{ #category : #'instance creation' }
SSDPMessage class >> from: aDatagram [
	| notificationClass |
	notificationClass := self subclasses 
		detect: [ :one | (one represents: aDatagram) ] 
		ifNone: [ "Not an SSDP datagram" ^nil ].
	^notificationClass fromDatagram: aDatagram
]

{ #category : #'instance creation' }
SSDPMessage class >> fromDatagram: aDatagram [
	
	^self new initializeFrom: aDatagram
]

{ #category : #testing }
SSDPMessage class >> represents: aDatagram [
	^self subclassResponsibility
]

{ #category : #'initialize - release' }
SSDPMessage >> initializeFrom: aDatagram [
	^self subclassResponsibility
]

{ #category : #'initialize - release' }
SSDPMessage >> relatedTo: aService [
	^aService uniqueServiceName = uniqueServiceName 
]

{ #category : #accessing }
SSDPMessage >> serviceType [
	^serviceType
]

{ #category : #accessing }
SSDPMessage >> uniqueServiceName [
	^uniqueServiceName
]
