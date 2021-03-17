/*
 *  Copyright (C) 2021 Intel Corporation
 *  SPDX-License-Identifier: BSD-3-Clause
 */

package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"
	"reflect"
	"strconv"
	"strings"

	"github.com/antchfx/jsonquery"
	"github.com/intel-secl/intel-secl/v3/pkg/lib/host-connector/types"
	"github.com/intel-secl/intel-secl/v3/pkg/model/hvs"
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
	"//host_info/hardware_features/SUEFI/enabled//*[text()='true']": "//hardware/feature/SUEFI/enabled//*[text()='true']",
	"//host_info/hardware_features/cbnt/enabled//*[text()='true']":  "//hardware/feature/CBNT/enabled//*[text()='true']",
	"//host_info/vendor//*[text()='Linux']":                         "//meta/vendor//*[text()='INTEL']",
	"//host_info/tpm_version//*[text()='2.0']":                      "//meta/description/tpm_version//*[text()='2.0']"}

var flavorTemplatePath = "/opt/hvs-flavortemplates"

//getFlavorTemplates method is used to get the flavor templates based on old flavor part file
func getFlavorTemplates(body []byte) ([]hvs.FlavorTemplate, error) {
	var defaultFlavorTemplates []string

	//read the flavor template file
	templates, err := ioutil.ReadDir(flavorTemplatePath)
	if err != nil {
		return nil, fmt.Errorf("Error in reading flavor template files")
	}
	for _, template := range templates {
		path := flavorTemplatePath + "/" + template.Name()
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
	oldFlavorPartFilePath := flag.String("o", "", "old flavor part json file")
	versionFlag := flag.Bool("version", false, "Print the current version and exit")
	newFlavorPartFilePath := flag.String("n", "", "new flavor part json file")

	// Showing useful information when the user enters the -h|--help option
	flag.Usage = func() {
		if len(os.Args) <= 2 && !*versionFlag && *oldFlavorPartFilePath == "" {
			fmt.Println(helpStr)
		} else {
			fmt.Println("Invalid Command Usage")
			fmt.Printf(helpStr)
		}
	}
	flag.Parse()

	// Show the current version when the user enters the -version option
	if *versionFlag && *oldFlavorPartFilePath != "" {
		fmt.Println("Invalid Command Usage")
		fmt.Printf(helpStr)
		os.Exit(1)
	} else if *versionFlag && *oldFlavorPartFilePath == "" {
		fmt.Println("Current build version: ", BuildVersion)
		os.Exit(1)
	} else if *oldFlavorPartFilePath == "" {
		// Checks for the file data that was entered by the user
		fmt.Println("Error: Old flavor part json file path is missing")
		fmt.Printf(helpStr)
		os.Exit(1)
	}

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
	templates, err := getFlavorTemplates(body)
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

	for flavorIndex, flavor := range oldFlavorPart.SignedFlavor {
		//Updating meta section
		if flavor.Flavor.Hardware != nil && flavor.Flavor.Hardware.Feature.CBNT.Enabled != nil && flavor.Flavor.Hardware.Feature.CBNT.Enabled.(bool) {
			oldFlavorPart.SignedFlavor[flavorIndex].Flavor.Meta.Description.CbntEnabled = true
		} else if flavor.Flavor.Hardware != nil && flavor.Flavor.Hardware.Feature.SUEFI != nil && flavor.Flavor.Hardware.Feature.SUEFI.Enabled {
			oldFlavorPart.SignedFlavor[flavorIndex].Flavor.Meta.Description.SuefiEnabled = true
		}

		if flavor.Flavor.Meta.Vendor == intelVendor {
			oldFlavorPart.SignedFlavor[flavorIndex].Flavor.Meta.Description.Vendor = "Linux"
		} else if flavor.Flavor.Meta.Vendor == vmwareVendor {
			oldFlavorPart.SignedFlavor[flavorIndex].Flavor.Meta.Description.Vendor = "VMware"
		}

		//Updating hardware section
		if flavor.Flavor.Hardware != nil {
			//TXT
			if flavor.Flavor.Hardware.Feature.TXT.Enabled != nil {
				oldFlavorPart.SignedFlavor[flavorIndex].Flavor.Hardware.Feature.TXT.Enabled = strconv.FormatBool(flavor.Flavor.Hardware.Feature.TXT.Enabled.(bool))
				oldFlavorPart.SignedFlavor[flavorIndex].Flavor.Hardware.Feature.TXT.Supported = oldFlavorPart.SignedFlavor[flavorIndex].Flavor.Hardware.Feature.TXT.Enabled.(string)
			} else {
				//if the TXT section not present in oldflavorpart json,assign false to it
				oldFlavorPart.SignedFlavor[flavorIndex].Flavor.Hardware.Feature.TXT.Enabled = "false"
				oldFlavorPart.SignedFlavor[flavorIndex].Flavor.Hardware.Feature.TXT.Supported = "false"
			}

			//TPM
			if flavor.Flavor.Hardware.Feature.TPM.Enabled != nil {
				oldFlavorPart.SignedFlavor[flavorIndex].Flavor.Hardware.Feature.TPM.Enabled = strconv.FormatBool(flavor.Flavor.Hardware.Feature.TPM.Enabled.(bool))
				oldFlavorPart.SignedFlavor[flavorIndex].Flavor.Hardware.Feature.TPM.Supported = oldFlavorPart.SignedFlavor[flavorIndex].Flavor.Hardware.Feature.TPM.Enabled.(string)
				oldFlavorPart.SignedFlavor[flavorIndex].Flavor.Hardware.Feature.TPM.Meta.TPMVersion = flavor.Flavor.Hardware.Feature.TPM.Version
				flavor.Flavor.Hardware.Feature.TPM.Version = ""
				oldFlavorPart.SignedFlavor[flavorIndex].Flavor.Hardware.Feature.TPM.Meta.PCRBanks = flavor.Flavor.Hardware.Feature.TPM.PcrBanks
				flavor.Flavor.Hardware.Feature.TPM.PcrBanks = nil
			} else {
				//if the TPM section not present in oldflavorpart json,assign false to it
				oldFlavorPart.SignedFlavor[flavorIndex].Flavor.Hardware.Feature.TPM.Enabled = "false"
				oldFlavorPart.SignedFlavor[flavorIndex].Flavor.Hardware.Feature.TPM.Supported = "false"
			}

			//CBNT
			if flavor.Flavor.Hardware.Feature.CBNT.Enabled != nil {
				oldFlavorPart.SignedFlavor[flavorIndex].Flavor.Hardware.Feature.CBNT.Enabled = strconv.FormatBool(flavor.Flavor.Hardware.Feature.CBNT.Enabled.(bool))
				oldFlavorPart.SignedFlavor[flavorIndex].Flavor.Hardware.Feature.CBNT.Supported = oldFlavorPart.SignedFlavor[flavorIndex].Flavor.Hardware.Feature.CBNT.Enabled.(string)
				oldFlavorPart.SignedFlavor[flavorIndex].Flavor.Hardware.Feature.CBNT.Meta.Profile = flavor.Flavor.Hardware.Feature.CBNT.Profile
				flavor.Flavor.Hardware.Feature.CBNT.Profile = ""
			} else {
				//if the CBNT section not present in oldflavorpart json,assign false to it
				oldFlavorPart.SignedFlavor[flavorIndex].Flavor.Hardware.Feature.CBNT.Enabled = "false"
				oldFlavorPart.SignedFlavor[flavorIndex].Flavor.Hardware.Feature.CBNT.Supported = "false"
			}

			//UEFI
			if flavor.Flavor.Hardware.Feature.SUEFI != nil {
				oldFlavorPart.SignedFlavor[flavorIndex].Flavor.Hardware.Feature.UEFI.Enabled = flavor.Flavor.Hardware.Feature.SUEFI.Enabled
				oldFlavorPart.SignedFlavor[flavorIndex].Flavor.Hardware.Feature.UEFI.Supported = flavor.Flavor.Hardware.Feature.SUEFI.Enabled
				oldFlavorPart.SignedFlavor[flavorIndex].Flavor.Hardware.Feature.UEFI.Meta.SecureBootEnabled = flavor.Flavor.Hardware.Feature.SUEFI.Enabled
				flavor.Flavor.Hardware.Feature.SUEFI = nil
			}
		}

		//removing the signature from the flavors
		//since the final flavor part file is not a signed flavor(only the flavor collection)
		oldFlavorPart.SignedFlavor[flavorIndex].Signature = ""

		// Copying the pcrs sections from old flavor part to new flavor part
		if flavor.Flavor.Pcrs == nil {
			continue
		}

		for _, template := range templates {
			oldFlavorPart.SignedFlavor[flavorIndex].Flavor.Meta.Description.FlavorTemplateIds = append(oldFlavorPart.SignedFlavor[flavorIndex].Flavor.Meta.Description.FlavorTemplateIds, template.ID)
			flavorname := flavor.Flavor.Meta.Description.FlavorPart
			rules, pcrsmap := getPcrRules(flavorname, template)
			if rules != nil && pcrsmap != nil {
				//Update PCR section
				flavor.Flavor.PcrLogs = updatePcrSection(flavor.Flavor.Pcrs, rules, pcrsmap)
			} else {
				continue
			}
		}
		oldFlavorPart.SignedFlavor[flavorIndex].Flavor.Pcrs = nil
		oldFlavorPart.SignedFlavor[flavorIndex].Flavor.PcrLogs = flavor.Flavor.PcrLogs
	}

	//getting the final data
	finalFlavorPart, err := json.Marshal(oldFlavorPart.SignedFlavor)
	if err != nil {
		fmt.Println("Error in marshaling the final flavor part file")
		os.Exit(1)
	}

	//Printing the final flavor part file in console
	fmt.Println("New flavor part json:\n", string(finalFlavorPart))

	//writing the new flavor part into the local file
	if *newFlavorPartFilePath != "" {
		// Checking if the output file path is json
		if fileExtension := filepath.Ext(*newFlavorPartFilePath); fileExtension != ".json" {
			fmt.Println("\nError in validating the new flavor part file path - the file '%s' is not json: ", *newFlavorPartFilePath)
			os.Exit(1)
		}
		data := []byte(finalFlavorPart)
		err = ioutil.WriteFile(*newFlavorPartFilePath, data, 0644)
		if err != nil {
			fmt.Println("Error in writing the new flavor part json in local file")
			os.Exit(1)
		}
	}
}

//updatePcrSection method is used to update the pcr section in new flavor part
func updatePcrSection(Pcrs map[string]map[string]PcrEx, rules []hvs.PcrRules, pcrsmap map[int]string) []types.PCRS {
	var newFlavorPcrs []types.PCRS
	newFlavorPcrs = make([]types.PCRS, len(pcrsmap))

	for bank, pcrMap := range Pcrs {
		index := 0
		for mapIndex, templateBank := range pcrsmap {
			pcrIndex := types.PcrIndex(mapIndex)

			if types.SHAAlgorithm(bank) != types.SHAAlgorithm(templateBank) {
				break
			}
			if expectedPcrEx, ok := pcrMap[pcrIndex.String()]; ok {
				newFlavorPcrs[index].PCR.Index = mapIndex
				newFlavorPcrs[index].PCR.Bank = bank
				newFlavorPcrs[index].Measurement = expectedPcrEx.Value
				newFlavorPcrs[index].PCRMatches = *rules[index].PcrMatches

				var newTpmEvents []types.EventLogCriteria
				if expectedPcrEx.Event != nil && !reflect.ValueOf(rules[index].EventlogEquals).IsZero() {
					newFlavorPcrs[index].EventlogEqual = new(types.EventLogEqual)
					if rules[index].EventlogEquals.ExcludingTags != nil {
						newFlavorPcrs[index].EventlogEqual.ExcludeTags = rules[index].EventlogEquals.ExcludingTags
					}

					newTpmEvents = make([]types.EventLogCriteria, len(expectedPcrEx.Event))
					for eventIndex, oldEvents := range expectedPcrEx.Event {
						newTpmEvents[eventIndex].TypeName = oldEvents.Label
						newTpmEvents[eventIndex].Tags = append(newTpmEvents[eventIndex].Tags, oldEvents.Label)
						newTpmEvents[eventIndex].Measurement = oldEvents.Value
						newTpmEvents[eventIndex].TypeID = eventIDList[oldEvents.Label]
					}
					newFlavorPcrs[index].EventlogEqual.Events = newTpmEvents
					newTpmEvents = nil
				}

				if expectedPcrEx.Event != nil && !reflect.ValueOf(rules[index].EventlogIncludes).IsZero() {
					newTpmEvents = make([]types.EventLogCriteria, len(expectedPcrEx.Event))
					for eventIndex, oldEvents := range expectedPcrEx.Event {
						newTpmEvents[eventIndex].TypeName = oldEvents.Label
						newTpmEvents[eventIndex].Tags = append(newTpmEvents[eventIndex].Tags, oldEvents.Label)
						newTpmEvents[eventIndex].Measurement = oldEvents.Value
						newTpmEvents[eventIndex].TypeID = eventIDList[oldEvents.Label]
					}
					newFlavorPcrs[index].EventlogIncludes = newTpmEvents
					newTpmEvents = nil
				}
			}
			index++
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
