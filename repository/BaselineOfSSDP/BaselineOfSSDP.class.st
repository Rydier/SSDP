Class {
	#name : #BaselineOfSSDP,
	#superclass : #BaselineOf,
	#category : #BaselineOfSSDP
}

{ #category : #baseline }
BaselineOfSSDP >> baseline: spec [
	<baseline>
	spec 
		for: #common 
		do: [
			spec group: 'default' with: #('SSDP')
		].
	spec 
		for: #pharo 
		do: [ spec package: 'SSDP' ].
	spec 
		for: #squeak 
		do: [ 
			spec package: 'SSDPPrerequisites-Squeak'.
			spec package: 'SSDP-Squeak' with: [ spec requires: 'SSDPPrerequisites-Squeak' ].
			spec package: 'SSDP' with: [ spec requires: 'SSDP-Squeak' ].
		]
]
