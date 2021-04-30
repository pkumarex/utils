/*
 * Copyright (C) 2021 Intel Corporation
 * SPDX-License-Identifier: BSD-3-Clause
 */
package main

import (
	"time"

	"github.com/google/uuid"
)

// OldFlavorPart is a list of SignedFlavor objects
type OldFlavorPart struct {
	SignedFlavor []SignedFlavors `json:"signed_flavors"`
}

// SignedFlavor combines the Flavor along with the cryptographically signed hash that authenticates its source
type SignedFlavors struct {
	Flavor    Flavor `json:"flavor,omitempty"`
	Signature string `json:"signature,omitempty"`
}

// Flavor is a standardized set of expectations that determines what platform
// measurements will be considered “trusted.”
type Flavor struct {
	// Meta section is mandatory for all Flavor types
	Meta Meta  `json:"meta"`
	Bios *Bios `json:"bios,omitempty"`
	// Hardware section is unique to Platform Flavor type
	Hardware *Hardware                   `json:"hardware,omitempty"`
	Pcrs     map[string]map[string]PcrEx `json:"pcrs,omitempty"`
	// External section is unique to AssetTag Flavor type
	External *External `json:"external,omitempty"`
	Software *Software `json:"software,omitempty"`
}

// Meta holds metadata information related to the Flavor
type Meta struct {
	Schema      *Schema     `json:"schema,omitempty"`
	ID          uuid.UUID   `json:"id"`
	Realm       string      `json:"realm,omitempty"`
	Description Description `json:"description,omitempty"`
	Vendor      string      `json:"vendor,omitempty"`
}

// PcrEx holds the details of the pcr information
type PcrEx struct {
	Value string     `json:"value"`
	Event []EventLog `json:"event,omitempty"`
}

// Bios holds details of the Bios vendor firmware information
type Bios struct {
	BiosName    string `json:"bios_name,omitempty"`
	BiosVersion string `json:"bios_version,omitempty"`
}

// Hardware contains information about the host's Hardware, Processor and Platform Features
type Hardware struct {
	Vendor         string   `json:"vendor,omitempty"`
	ProcessorInfo  string   `json:"processor_info,omitempty"`
	ProcessorFlags string   `json:"processor_flags,omitempty"`
	Feature        *Feature `json:"feature,omitempty"`
}

// External is a component of flavor that encloses the AssetTag cert
type External struct {
	AssetTag AssetTag `json:"asset_tag,omitempty"`
}

// Software consists of integrity measurements of Software/OS related resources
type Software struct {
	Measurements   map[string]FlavorMeasurement `json:"measurements,omitempty"`
	CumulativeHash string                       `json:"cumulative_hash,omitempty"`
}

type FlavorMeasurement struct {
	Type       MeasurementType `json:"type"`
	Value      string          `json:"value"`
	Path       string          `json:"Path"`
	Include    string          `json:"Include,omitempty"`
	Exclude    string          `json:"Exclude,omitempty"`
	SearchType string          `json:"SearchType,omitempty"`
	FilterType string          `json:"FilterType,omitempty"`
}

type MeasurementType string

const (
	MeasurementTypeFile    MeasurementType = "fileMeasurementType"
	MeasurementTypeDir     MeasurementType = "directoryMeasurementType"
	MeasurementTypeSymlink MeasurementType = "symlinkMeasurementType"
)

// Schema defines the Uri of the schema
type Schema struct {
	Uri string `json:"uri,omitempty"`
}

// Description contains information about the host hardware identifiers
type Description struct {
	FlavorPart      string     `json:"flavor_part,omitempty"`
	Source          string     `json:"source,omitempty"`
	Label           string     `json:"label,omitempty"`
	IPAddress       string     `json:"ip_address,omitempty"`
	BiosName        string     `json:"bios_name,omitempty"`
	BiosVersion     string     `json:"bios_version,omitempty"`
	OsName          string     `json:"os_name,omitempty"`
	OsVersion       string     `json:"os_version,omitempty"`
	VmmName         string     `json:"vmm_name,omitempty"`
	VmmVersion      string     `json:"vmm_version,omitempty"`
	TpmVersion      string     `json:"tpm_version,omitempty"`
	HardwareUUID    *uuid.UUID `json:"hardware_uuid,omitempty"`
	Comment         string     `json:"comment,omitempty"`
	TbootInstalled  *bool      `json:"tboot_installed,string,omitempty"`
	DigestAlgorithm string     `json:"digest_algorithm,omitempty"`
}

type EventLog struct {
	DigestType string            `json:"digest_type"`
	Value      string            `json:"value"`
	Label      string            `json:"label"`
	Info       map[string]string `json:"info"`
}

// Feature encapsulates the presence of various Platform security features on the Host hardware
type Feature struct {
	AES_NI *AES_NI `json:"AES_NI,omitempty"`
	SUEFI  *SUEFI  `json:"SUEFI,omitempty"`
	TXT    *TXT    `json:"TXT"`
	TPM    *TPM    `json:"TPM"`
	CBNT   *CBNT   `json:"CBNT"`
}

// AES_NI
type AES_NI struct {
	Enabled bool `json:"enabled,omitempty"`
}

// TXT
type TXT struct {
	Enabled bool `json:"enabled"`
}

// TPM
type TPM struct {
	Enabled  bool     `json:"enabled"`
	Version  string   `json:"version,omitempty"`
	PcrBanks []string `json:"pcr_banks,omitempty"`
}

//CBNT
type CBNT struct {
	Enabled bool   `json:"enabled"`
	Profile string `json:"profile,omitempty"`
}

// SUEFI
type SUEFI struct {
	Enabled bool `json:"enabled,omitempty"`
}

// AssetTag is used to hold the Asset Tag certificate provisioned by VS for the host
type AssetTag struct {
	TagCertificate X509AttributeCertificate `json:"tag_certificate"`
}

// X509AttributeCertificate holds a subset of x509.Certificate that has relevant information for Flavor
type X509AttributeCertificate struct {
	Encoded           []byte      `json:"encoded"`
	Issuer            string      `json:"issuer"`
	SerialNumber      int64       `json:"serial_number"`
	Subject           string      `json:"subject"`
	NotBefore         time.Time   `json:"not_before"`
	NotAfter          time.Time   `json:"not_after"`
	Attributes        []Attribute `json:"attribute,omitempty"`
	FingerprintSha384 string      `json:"fingerprint_sha384"`
}

// Attribute is used to store the custom Asset Tags embedded in the tag certificate
type Attribute struct {
	AttrType struct {
		ID string `json:"id"`
	} `json:"attr_type"`
	AttributeValues []AttrObjects `json:"attribute_values,omitempty"`
}

// AttrObject holds the individual TagKeyValue Pair - TagKVAttribute which is decoded from ASN.1 values
type AttrObjects struct {
	KVPair TagKvAttribute `json:"objects"`
}

// TagKvAttribute struct is the key-value asset-tag attributes
type TagKvAttribute struct {
	Key   string `json:"name"`
	Value string `json:"value"`
}
