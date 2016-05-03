Class {
	#name : #SHA256,
	#superclass : #SecureHashAlgorithm,
	#category : #'SSDPPrerequisites-Squeak'
}

{ #category : #public }
SHA256 >> hashStream: aStream [
	"Split input in two and run each through SHA. Yes, I know this isn't actually SHA256, but this is just a hack to get long enough output for SSDP uuid generation."
	|elements str1 str2 output |
	
	elements := aStream size - aStream position // 2.
	str1 := (aStream next: elements) readStream.
	str2 := (aStream upToEnd) readStream.
	output := ByteArray new: 40.
	output replaceFrom: 1 to: 20 with: (super hashStream: str1 ) startingAt: 1.
	output replaceFrom: 21 to: 40 with: (super hashStream: str2 ) startingAt: 1.
	^output.
	
]
