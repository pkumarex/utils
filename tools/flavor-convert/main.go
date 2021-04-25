/*
 *  Copyright (C) 2021 Intel Corporation
 *  SPDX-License-Identifier: BSD-3-Clause
 */

package main

import (
	"crypto/rand"
	"crypto/rsa"
	"encoding/json"
	"flag"
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"
	"reflect"
	"strings"

	"github.com/antchfx/jsonquery"
	"github.com/google/uuid"
	"github.com/intel-secl/intel-secl/v3/pkg/lib/common/crypt"
	"github.com/intel-secl/intel-secl/v3/pkg/lib/flavor/model"
	connector "github.com/intel-secl/intel-secl/v3/pkg/lib/host-connector"
	"github.com/intel-secl/intel-secl/v3/pkg/lib/host-connector/constants"
	"github.com/intel-secl/intel-secl/v3/pkg/lib/host-connector/types"
	"github.com/intel-secl/intel-secl/v3/pkg/model/hvs"
	"github.com/jinzhu/copier"
)

// EventIDList - define map for event id
var eventIDList = map[string]string{
	"PCR_MAPPING":          "0x401",
	"HASH_START":           "0x402",
	"COMBINED_HASH":        "0x403",
	"MLE_HASH":             "0x404",
	"BIOSAC_REG_DATA":      "0x40a",
	"CPU_SCRTM_STAT":       "0x40b",
	"LCP_CONTROL_HASH":     "0x40c",
	"ELEMENTS_HASH":        "0x40d",
	"STM_HASH":             "0x40e",
	"OSSINITDATA_CAP_HASH": "0x40f",
	"SINIT_PUBKEY_HASH":    "0x410",
	"LCP_HASH":             "0x411",
	"LCP_DETAILS_HASH":     "0x412",
	"LCP_AUTHORITIES_HASH": "0x413",
	"NV_INFO_HASH":         "0x414",
	"EVTYPE_KM_HASH":       "0x416",
	"EVTYPE_BPM_HASH":      "0x417",
	"EVTYPE_KM_INFO_HASH":  "0x418",
	"EVTYPE_BPM_INFO_HASH": "0x419",
	"EVTYPE_BOOT_POL_HASH": "0x41a",
	"CAP_VALUE":            "0x4ff",
	"tb_policy":            "0x501",
	"vmlinuz":              "0x501",
	"initrd":               "0x501",
	"asset-tag":            "0x501",
}

const (
	intelVendor  = "INTEL"
	vmwareVendor = "VMWARE"

	platformFlavor   = "PLATFORM"
	osFlavor         = "OS"
	hostUniqueFlavor = "HOST_UNIQUE"
)

var BuildVersion string

const helpStr = `Usage:
flavor-convert <command> [argument]
	
Available Command:
	-o                To provide old flavor part json filepath
	-n                To provide new flavor part json filepath
	-h|--help         Show this help message
	-version          Print the current version
`

//To map the conditions in the flavor template with old flavor part
var flavorTemplateConditions = map[string]string{"//host_info/tboot_installed//*[text()='true']": "//meta/description/tboot_installed//*[text()='true']",
	"//host_info/hardware_features/UEFI/meta/secure_boot_enabled//*[text()='true']": "//hardware/feature/SUEFI/enabled//*[text()='true']",
	"//host_info/hardware_features/CBNT/enabled//*[text()='true']":                  "//hardware/feature/CBNT/enabled//*[text()='true']",
	"//host_info/os_name//*[text()='RedHatEnterprise']":                             "//meta/vendor//*[text()='INTEL']",
	"//host_info/os_name//*[text()='VMware ESXi']":                                  "//meta/vendor//*[text()='VMWARE']",
	"//host_info/hardware_features/TPM/meta/tpm_version//*[text()='2.0']":           "//meta/description/tpm_version//*[text()='2.0']",
	"//host_info/hardware_features/TPM/meta/tpm_version//*[text()='1.2']":           "//meta/description/tpm_version//*[text()='1.2']"}

//getFlavorTemplates method is used to get the flavor templates based on old flavor part file
func getFlavorTemplates(body []byte, flavorTemplateFilePath string) ([]hvs.FlavorTemplate, error) {
	var defaultFlavorTemplates []string

	//read the flavor template file
	templates, err := ioutil.ReadDir(flavorTemplateFilePath)
	if err != nil {
		return nil, fmt.Errorf("Error in reading flavor template files")
	}
	for _, template := range templates {
		path := flavorTemplateFilePath + "/" + template.Name()
		data, err := ioutil.ReadFile(path)
		if err != nil {
			return nil, fmt.Errorf("Error in reading the template file - ", template.Name())
		}
		defaultFlavorTemplates = append(defaultFlavorTemplates, string(data))
	}

	// finding the correct template to apply
	filteredTemplate, err := findTemplatesToApply(body, defaultFlavorTemplates)
	if err != nil {
		return nil, fmt.Errorf("Error in getting the template file based on old flavorpart")
	}

	return filteredTemplate, nil
}

//findTemplatesToApply method is used to find the correct templates to apply to convert flavor part
func findTemplatesToApply(oldFlavorPart []byte, defaultFlavorTemplates []string) ([]hvs.FlavorTemplate, error) {
	var filteredTemplates []hvs.FlavorTemplate
	var conditionEval bool

	oldFlavorPartJson, err := jsonquery.Parse(strings.NewReader(string(oldFlavorPart)))
	if err != nil {
		return nil, fmt.Errorf("Error in parsing the old flavor part json")
	}

	for _, template := range defaultFlavorTemplates {
		flavorTemplate := hvs.FlavorTemplate{}

		err := json.Unmarshal([]byte(template), &flavorTemplate)
		if err != nil {
			return nil, fmt.Errorf("Error in unmarshaling the flavor template")
		}
		if flavorTemplate.Label == "" {
			continue
		}
		conditionEval = false

		for _, condition := range flavorTemplate.Condition {
			conditionEval = true
			flavorPartCondition := flavorTemplateConditions[condition]
			expectedData, _ := jsonquery.Query(oldFlavorPartJson, flavorPartCondition)
			if expectedData == nil {
				conditionEval = false
				break
			}
		}
		if conditionEval == true {
			filteredTemplates = append(filteredTemplates, flavorTemplate)
		}
	}

	return filteredTemplates, nil
}

//checkIfValidFile method is used to check if the given input file path is valid or not
func checkIfValidFile(filename string) (bool, error) {
	// Checking if the input file is json
	if fileExtension := filepath.Ext(filename); fileExtension != ".json" {
		return false, fmt.Errorf("File '%s' is not json", filename)
	}

	// Checking if filepath entered belongs to an existing file
	if _, err := os.Stat(filename); err != nil && os.IsNotExist(err) {
		return false, fmt.Errorf("File %s does not exist", filename)
	}

	// returns true if this is a valid file
	return true, nil
}

//main method implements migration of old format of flavor part to new format
func main() {
	oldFlavorPartFilePath := flag.String("o", "", "old flavor part folder path")
	flavorTemplateFilePath := flag.String("f", "", "flavor templates folder path")
	versionFlag := flag.Bool("version", false, "Print the current version and exit")
	signingKeyFilePath := flag.String("k", "", "signing-key file")

	// Showing useful information when the user enters the -h|--help option
	flag.Usage = func() {
		if len(os.Args) <= 2 && !*versionFlag && *oldFlavorPartFilePath == "" &&
			*flavorTemplateFilePath == "" {
			fmt.Println(helpStr)
		} else {
			fmt.Println("Invalid Command Usage")
			fmt.Printf(helpStr)
		}
	}
	flag.Parse()

	// Show the current version when the user enters the -version option
	if *versionFlag && *oldFlavorPartFilePath != "" &&
		*flavorTemplateFilePath != "" {
		fmt.Println("Invalid Command Usage")
		fmt.Printf(helpStr)
		os.Exit(1)
	} else if *versionFlag && *oldFlavorPartFilePath == "" &&
		*flavorTemplateFilePath == "" {
		fmt.Println("Current build version: ", BuildVersion)
		os.Exit(1)
	} else if *oldFlavorPartFilePath == "" {
		// Checks for the file data that was entered by the user
		fmt.Println("Error: Old flavor part file path is missing")
		fmt.Printf(helpStr)
		os.Exit(1)
	} else if *flavorTemplateFilePath == "" {
		// Checks for the file data that was entered by the user
		fmt.Println("Error: Flavor templates file path is missing")
		fmt.Printf(helpStr)
		os.Exit(1)
	}

	// Get the private key if signing key file path is provided
	flavorSignKey := getPrivateKey(*signingKeyFilePath)

	// Validating the old flavor part file path entered
	if valid, err := checkIfValidFile(*oldFlavorPartFilePath); err != nil && !valid {
		fmt.Println("Error in validating the input file path - ", err)
		os.Exit(1)
	}

	//reading the data from oldFlavorPartFilePath
	body, err := ioutil.ReadFile(*oldFlavorPartFilePath)
	if err != nil {
		fmt.Println("Error in reading the old flavor part file data")
		os.Exit(1)
	}

	//get the flavor template based on old flavor part file
	templates, err := getFlavorTemplates(body, *flavorTemplateFilePath)
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}

	var oldFlavorPart OldFlavorPart

	//unmarshaling the old flavor part file into OldFlavorPart struct
	err = json.Unmarshal(body, &oldFlavorPart)
	if err != nil {
		fmt.Println("Error in unmarshaling the old flavor part file", err)
		os.Exit(1)
	}

	var newFlavor []hvs.Flavor
	newFlavor = make([]hvs.Flavor, len(oldFlavorPart.SignedFlavor))

	for flavorIndex, flavor := range oldFlavorPart.SignedFlavor {

		//Updating meta section
		copier.Copy(&newFlavor[flavorIndex].Meta, &flavor.Flavor.Meta)
		if flavor.Flavor.Meta.Vendor == intelVendor {
			newFlavor[flavorIndex].Meta.Vendor = constants.VendorIntel
		} else if flavor.Flavor.Meta.Vendor == vmwareVendor {
			newFlavor[flavorIndex].Meta.Vendor = constants.VendorVMware
		} else {
			newFlavor[flavorIndex].Meta.Vendor = constants.VendorUnknown
		}

		//Update description
		var description = make(map[string]interface{})
		description = updateDescription(description, flavor.Flavor.Meta, flavor.Flavor.Hardware)
		newFlavor[flavorIndex].Meta.Description = description

		//Updating BIOS section
		if flavor.Flavor.Bios != nil {
			newFlavor[flavorIndex].Bios = new(model.Bios)
			copier.Copy(newFlavor[flavorIndex].Bios, flavor.Flavor.Bios)
		}

		//Updating Hardware section
		if flavor.Flavor.Hardware != nil {
			newFlavor[flavorIndex].Hardware = new(model.Hardware)
			copier.Copy(newFlavor[flavorIndex].Hardware, flavor.Flavor.Hardware)

			//TXT
			newFlavor[flavorIndex].Hardware.Feature.TXT.Supported = newFlavor[flavorIndex].Hardware.Feature.TXT.Enabled

			//TPM
			newFlavor[flavorIndex].Hardware.Feature.TPM.Supported = newFlavor[flavorIndex].Hardware.Feature.TPM.Enabled
			newFlavor[flavorIndex].Hardware.Feature.TPM.Meta.TPMVersion = flavor.Flavor.Hardware.Feature.TPM.Version
			newFlavor[flavorIndex].Hardware.Feature.TPM.Meta.PCRBanks = flavor.Flavor.Hardware.Feature.TPM.PcrBanks

			//CBNT
			if flavor.Flavor.Hardware.Feature.CBNT != nil {
				newFlavor[flavorIndex].Hardware.Feature.CBNT.Supported = newFlavor[flavorIndex].Hardware.Feature.CBNT.Enabled
				newFlavor[flavorIndex].Hardware.Feature.CBNT.Meta.Profile = flavor.Flavor.Hardware.Feature.CBNT.Profile
			}

			//UEFI
			if flavor.Flavor.Hardware.Feature.SUEFI != nil {
				newFlavor[flavorIndex].Hardware.Feature.UEFI.Supported = newFlavor[flavorIndex].Hardware.Feature.UEFI.Enabled
				newFlavor[flavorIndex].Hardware.Feature.UEFI.Meta.SecureBootEnabled = flavor.Flavor.Hardware.Feature.SUEFI.Enabled
			}
		}

		//Updating external section
		if flavor.Flavor.External != nil {
			newFlavor[flavorIndex].External = new(model.External)
			copier.Copy(newFlavor[flavorIndex].External, flavor.Flavor.External)
		}

		//Updating Software section
		if flavor.Flavor.Software != nil {
			newFlavor[flavorIndex].Software = new(model.Software)
			copier.Copy(newFlavor[flavorIndex].Software, flavor.Flavor.Software)
		}

		// Copying the pcrs sections from old flavor part to new flavor part
		if flavor.Flavor.Pcrs != nil {
			var flavorTemplateIDList []uuid.UUID
			for _, template := range templates {
				flavorTemplateIDList = append(flavorTemplateIDList, template.ID)
				flavorname := flavor.Flavor.Meta.Description.FlavorPart
				rules, pcrsmap := getPcrRules(flavorname, template)
				if rules != nil && pcrsmap != nil {
					//Update PCR section
					newFlavor[flavorIndex].Pcrs = updatePcrSection(flavor.Flavor.Pcrs, rules, pcrsmap, flavor.Flavor.Meta.Vendor)
				} else {
					continue
				}
			}
			newFlavor[flavorIndex].Meta.Description["flavor_template_ids"] = flavorTemplateIDList
		}
		flavorSection, err := json.Marshal(newFlavor[flavorIndex])
		if err != nil {
			fmt.Println("Error in marshaling the flavor section")
			os.Exit(1)
		}
		fmt.Println("\n" + string(flavorSection))

		signedFlavor, err := model.NewSignedFlavor(&newFlavor[flavorIndex], flavorSignKey)
		if err != nil {
			fmt.Println("Error in getting the signed flavor")
			os.Exit(1)
		}

		//used "@" delimiter to split the flavor and signature value in script
		fmt.Println("@" + signedFlavor.Signature)
	}
}

//updatePcrSection method is used to update the pcr section in new flavor part
func updatePcrSection(Pcrs map[string]map[string]PcrEx, rules []hvs.PcrRules, pcrsmap map[int]string, vendor string) []types.FlavorPcrs {
	var newFlavorPcrs []types.FlavorPcrs
	newFlavorPcrs = make([]types.FlavorPcrs, len(pcrsmap))

	for bank, pcrMap := range Pcrs {
		for index, rule := range rules {
			for mapIndex, templateBank := range pcrsmap {
				if mapIndex != rule.Pcr.Index {
					continue
				}
				pcrIndex := types.PcrIndex(mapIndex)
				if types.SHAAlgorithm(bank) != types.SHAAlgorithm(templateBank) {
					break
				}
				if expectedPcrEx, ok := pcrMap[pcrIndex.String()]; ok {
					newFlavorPcrs[index].Pcr.Index = mapIndex
					newFlavorPcrs[index].Pcr.Bank = bank
					newFlavorPcrs[index].Measurement = expectedPcrEx.Value
					if rule.PcrMatches != nil {
						newFlavorPcrs[index].PCRMatches = *rule.PcrMatches
					}
					var newTpmEvents []types.EventLog
					if rule.Pcr.Index == newFlavorPcrs[index].Pcr.Index &&
						rule.EventlogEquals != nil && expectedPcrEx.Event != nil && !reflect.ValueOf(rule.EventlogEquals).IsZero() {
						newFlavorPcrs[index].EventlogEqual = new(types.EventLogEqual)
						if rule.EventlogEquals.ExcludingTags != nil {
							newFlavorPcrs[index].EventlogEqual.ExcludeTags = rule.EventlogEquals.ExcludingTags
						}
						newTpmEvents = make([]types.EventLog, len(expectedPcrEx.Event))
						newTpmEvents = updateTpmEvents(expectedPcrEx.Event, newTpmEvents, vendor)
						newFlavorPcrs[index].EventlogEqual.Events = newTpmEvents
						newTpmEvents = nil
					}
					if rule.Pcr.Index == newFlavorPcrs[index].Pcr.Index && rule.EventlogIncludes != nil && expectedPcrEx.Event != nil && !reflect.ValueOf(rule.EventlogIncludes).IsZero() {
						newTpmEvents = make([]types.EventLog, len(expectedPcrEx.Event))
						newTpmEvents = updateTpmEvents(expectedPcrEx.Event, newTpmEvents, vendor)
						newFlavorPcrs[index].EventlogIncludes = newTpmEvents
						newTpmEvents = nil
					}
				}
			}
		}
	}

	return newFlavorPcrs
}

//getPcrRules method is used to get the pcr rules defined in the flavor template
func getPcrRules(flavorName string, template hvs.FlavorTemplate) ([]hvs.PcrRules, map[int]string) {
	pcrsmap := make(map[int]string)
	var rules []hvs.PcrRules

	if flavorName == platformFlavor && template.FlavorParts.Platform != nil {
		for _, rules := range template.FlavorParts.Platform.PcrRules {
			pcrsmap[rules.Pcr.Index] = rules.Pcr.Bank
		}
		rules = template.FlavorParts.Platform.PcrRules
		return rules, pcrsmap
	} else if flavorName == osFlavor && template.FlavorParts.OS != nil {
		for _, rules := range template.FlavorParts.OS.PcrRules {
			pcrsmap[rules.Pcr.Index] = rules.Pcr.Bank
		}
		rules = template.FlavorParts.OS.PcrRules
		return rules, pcrsmap
	} else if flavorName == hostUniqueFlavor && template.FlavorParts.HostUnique != nil {
		for _, rules := range template.FlavorParts.HostUnique.PcrRules {
			pcrsmap[rules.Pcr.Index] = rules.Pcr.Bank
		}
		rules = template.FlavorParts.HostUnique.PcrRules
		return rules, pcrsmap
	}

	return nil, nil
}

//updateTpmEvents method is used to update the tpm events
func updateTpmEvents(expectedPcrEvent []EventLog, newTpmEvents []types.EventLog, vendor string) []types.EventLog {

	//Updating the old event format into new event format
	for eventIndex, oldEvents := range expectedPcrEvent {
		if vendor == intelVendor {
			newTpmEvents[eventIndex].TypeName = oldEvents.Label
			newTpmEvents[eventIndex].Tags = append(newTpmEvents[eventIndex].Tags, oldEvents.Label)
			newTpmEvents[eventIndex].Measurement = oldEvents.Value
			newTpmEvents[eventIndex].TypeID = eventIDList[oldEvents.Label]
		} else if vendor == vmwareVendor {
			if oldEvents.Info["PackageName"] != "" {
				newTpmEvents[eventIndex].Tags = append(newTpmEvents[eventIndex].Tags, oldEvents.Info["ComponentName"], oldEvents.Info["EventName"]+"_"+oldEvents.Info["PackageName"]+"_"+oldEvents.Info["PackageVendor"])
			} else {
				newTpmEvents[eventIndex].Tags = append(newTpmEvents[eventIndex].Tags, oldEvents.Info["ComponentName"], oldEvents.Info["EventName"])
			}
			newTpmEvents[eventIndex].TypeName = oldEvents.Label
			newTpmEvents[eventIndex].Measurement = oldEvents.Value

			switch oldEvents.Info["EventType"] {
			case connector.TPM_SOFTWARE_COMPONENT_EVENT_TYPE:
				newTpmEvents[eventIndex].TypeID = connector.VIB_NAME_TYPE_ID
			case connector.TPM_COMMAND_EVENT_TYPE:
				newTpmEvents[eventIndex].TypeID = connector.COMMANDLINE_TYPE_ID
			case connector.TPM_OPTION_EVENT_TYPE:
				newTpmEvents[eventIndex].TypeID = connector.OPTIONS_FILE_NAME_TYPE_ID
			case connector.TPM_BOOT_SECURITY_OPTION_EVENT_TYPE:
				newTpmEvents[eventIndex].TypeID = connector.BOOT_SECURITY_OPTION_TYPE_ID
			}
		} else {
			fmt.Println("UNKNOWN VENDOR - unable to update tpm events")
			os.Exit(1)
		}
	}

	return newTpmEvents
}

//getPrivateKey method is used to get the private key from the inputkeypath if present else generates the newkey
func getPrivateKey(signingKeyFilePath string) *rsa.PrivateKey {
	var flavorSignKey *rsa.PrivateKey
	var err error
	if signingKeyFilePath != "" {
		key, err := crypt.GetPrivateKeyFromPKCS8File(signingKeyFilePath)
		if err != nil {
			fmt.Println("flavorgen/flavor_gen:main() Error getting private key %s", err)
			os.Exit(1)
		}
		flavorSignKey = key.(*rsa.PrivateKey)
	} else {
		flavorSignKey, err = rsa.GenerateKey(rand.Reader, 3072)
		if err != nil {
			fmt.Println(err, "flavorgen/flavor_create:createFlavor() Couldn't generate RSA key, failed to create flavorsinging key")
			os.Exit(1)
		}
	}
	return flavorSignKey
}

//updateDescription method is used to update the description section in flavor
func updateDescription(description map[string]interface{}, meta Meta, hardware *Hardware) map[string]interface{} {
	description[model.TbootInstalled] = meta.Description.TbootInstalled
	description[model.Label] = meta.Description.Label
	description[model.FlavorPart] = meta.Description.FlavorPart
	description[model.Source] = meta.Description.Source

	switch meta.Description.FlavorPart {
	case platformFlavor:
		description[model.BiosName] = meta.Description.BiosName
		description[model.BiosVersion] = meta.Description.BiosVersion
	case osFlavor:
		description[model.OsName] = meta.Description.OsName
		description[model.OsVersion] = meta.Description.OsVersion
		description[model.VmmName] = meta.Description.VmmName
		description[model.VmmVersion] = meta.Description.VmmVersion
	case hostUniqueFlavor:
		description[model.HardwareUUID] = meta.Description.HardwareUUID
		description[model.BiosName] = meta.Description.BiosName
		description[model.BiosVersion] = meta.Description.BiosVersion
		description[model.OsName] = meta.Description.OsName
		description[model.OsVersion] = meta.Description.OsVersion
	}

	if hardware != nil {
		description[model.TpmVersion] = hardware.Feature.TPM.Version
		if hardware.Feature.CBNT != nil && hardware.Feature.CBNT.Enabled {
			description["cbnt_enabled"] = true
		} else if hardware.Feature.SUEFI != nil && hardware.Feature.SUEFI.Enabled {
			description["suefi_enabled"] = true
		}
	}

	return description
}
