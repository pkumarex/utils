/*
 * Copyright (C) 2020 Intel Corporation
 * SPDX-License-Identifier: BSD-3-Clause
 */

package resource

import (
	"encoding/json"
	"github.com/gorilla/handlers"
	"github.com/gorilla/mux"
	"github.com/pkg/errors"
	"intel/isecl/lib/clients/v3"
	"intel/isecl/sgx_agent/v3/config"
	"intel/isecl/sgx_agent/v3/constants"
	"intel/isecl/sgx_agent/v3/utils"

	"bytes"
	"io/ioutil"
	"net/http"
	"strconv"
	"math/rand"
	"time"
)

type SGX_Discovery_Data struct {
	Sgx_supported       bool   `json:"sgx-supported"`
	Sgx_enabled         bool   `json:"sgx-enabled"`
	Flc_enabled         bool   `json:"flc-enabled"`
	Epc_startaddress    string `json:"epc-offset"`
	Epc_size            string `json:"epc-size"`
	sgx_Level           int
	maxEnclaveSizeNot64 int64
	maxEnclaveSize64    int64
}

type Paltform_Data struct {
	Encrypted_PPID string `json:"enc-ppid"`
	Pce_id         string `json:"pceid"`
	Cpu_svn        string `json:"cpusvn"`
	Pce_svn        string `json:"pcesvn"`
	Qe_id          string `json:"qeid"`
	Manifest       string `json:"Manifest"`
}

type PlatformResponse struct {
	SGXData SGX_Discovery_Data `json:"sgx-data"`
	PData   Paltform_Data      `json:"sgx-platform-data"`
}

var (
	flcEnabledCmd      = []string{"rdmsr", "-ax", "0x3A"} ///MSR.IA32_Feature_Control register tells availability of SGX
	pckIDRetrievalInfo = []string{"PCKIDRetrievalTool", "-f", "/opt/pckData"}
)

type SCSPushResponse struct {
	Status  string `json:"Status"`
	Message string `json:"Message"`
}

var sgxData SGX_Discovery_Data
var platformData Paltform_Data

func ProvidePlatformInfo(router *mux.Router) {
	log.Trace("resource/sgx_detection:ProvidePlatformInfo() Entering")
	defer log.Trace("resource/sgx_detection:ProvidePlatformInfo() Leaving")

	router.Handle("/host/{id}", handlers.ContentTypeHandler(getPlatformInfo(), "application/json")).Methods("GET")
}

func random(min int, max int) int {
	return rand.Intn(max-min) + min
}

///For any demo function
func Extract_SGXPlatformValues() error {
	sgxData.Sgx_supported = true
	sgxData.Sgx_enabled = true
	sgxData.Flc_enabled = true
	sgxData.Epc_startaddress = "0x70200000"
	sgxData.Epc_size = "189.5" + strconv.Itoa(rand.Intn(100)) + " MB"
	sgxData.sgx_Level = 12
	sgxData.maxEnclaveSizeNot64 = 11
	sgxData.maxEnclaveSize64 = 12
	platformData.Encrypted_PPID = strconv.Itoa(random(100000, 999999)) + "85b1ba8330b750b7a52fa03e8137c06ba050561d9d5a3391e16304809761ef9b8d04237ab7cee326a140c697fc60ab8eade69b39ae676e7b4201200b864f8e1737f47b1d20a431f2b2bcdfd4927ac330a897962a95e94597c682a8de74c8b6a99dd633bceb78515f58ed760acab856f55552dc868b77857f8ceeb88cd2f94a1fadd3d484c95203f064341fbc02b914560716873147ce0feb3f9581f9b911fcd60f9abd7d4d8e6f06a145964a6e5032a5e2721cf0d45493618036110ec3ff5b01084097acf2d9783241ac57b6826404f41eea380e55681cbc5fbcfd07368326dad1a67a54a48ba7aa2945b01d673c91edce044db2929b7cd5f21909513ef54ffc98fadcb94e31f358fe2dc95ff6fe3c8473052ec9b99abaf8501c5c1167b580546349e969d99f224ca0189c4e739cee48799b92909a175f59e2de49a741a0863d42780ab524a7420493e2fa35a191e0bd2b37e49d05c512f70bf46d26f25d6e809a007807cd4b00682bedbd5412553677c9e8af746064c233779195af2c"
	platformData.Pce_id = "0000"
	platformData.Cpu_svn = "0202ffffff8002000000010000000000"
	platformData.Pce_svn = "0a00"
	platformData.Qe_id = strconv.Itoa(random(10, 99)) + "bf2b6b" + strconv.Itoa(random(1000, 9999)) + "bb879a788a1c104f67ff"
	platformData.Manifest = "qwertyqwertyutreqwertyuiqwertyuytrewqwertyuytrewqwertyuytrewqwertyuqwertyuiopppoiuytrewqqwertyuioppoiuytrewqasdfghjmkqazwxsecdrtfvbgyhunjmi"
	log.Debug("EncryptedPPID: ", platformData.Encrypted_PPID)
	log.Debug("PCE_ID: ", platformData.Pce_id)
	log.Debug("CPUSVN: ", platformData.Cpu_svn)
	log.Debug("PCE ISVSVN: ", platformData.Pce_svn)
	log.Debug("QE_ID: ", platformData.Qe_id)
	return nil
}

///This is done in TA but we might need to do here

func check(e error) {
	if e != nil {
		panic(e)
	}
}

func getPlatformInfo() errorHandlerFunc {
	return func(httpWriter http.ResponseWriter, httpRequest *http.Request) error {
		log.Trace("resource/sgx_detection:GetPlatformInfo() Entering")
		defer log.Trace("resource/sgx_detection:GetPlatformInfo() Leaving")

		err := authorizeEndpoint(httpRequest, constants.HostDataReaderGroupName, true)
		if err != nil {
			return err
		}

		if httpRequest.Header.Get("Accept") != "application/json" {
			return &resourceError{Message: "Accept type not supported", StatusCode: http.StatusNotAcceptable}
		}

		conf := config.Global()
		if conf == nil {
			return errors.Wrap(errors.New("getPlatformInfo: Configuration pointer is null"), "Config error")
		}

		if conf.SGXAgentMode == constants.RegistrationMode {
			httpWriter.WriteHeader(http.StatusNotImplemented)
			log.Debug("getPlatformInfo: SGX Agent is in Registration mode. Returning 501 response.")
			return &resourceError{Message: err.Error(), StatusCode: http.StatusNotImplemented}
		}

		Extract_SGXPlatformValues()
		res := PlatformResponse{SGXData: sgxData, PData: platformData}

		httpWriter.Header().Set("Content-Type", "application/json")
		httpWriter.WriteHeader(http.StatusOK)
		js, err := json.Marshal(res)
		if err != nil {
			log.Debug("Marshalling unsuccessful")
			return &resourceError{Message: err.Error(), StatusCode: http.StatusInternalServerError}
		}

		_, err = httpWriter.Write(js)
		if err != nil {
			return &resourceError{Message: err.Error(), StatusCode: http.StatusInternalServerError}
		}
		slog.Info("Platform data retrieved by:", httpRequest.RemoteAddr)
		return nil
	}
}

func PushSGXData() (bool, error) {
	log.Trace("resource/sgx_detection.go: PushSGXData() Entering")
	defer log.Trace("resource/sgx_detection.go: PushSGXData() Leaving")
	client, err := clients.HTTPClientWithCADir(constants.TrustedCAsStoreDir)
	if err != nil {
		return false, errors.Wrap(err, "PushSGXData: Error in getting client object")
	}

	conf := config.Global()
	if conf == nil {
		return false, errors.Wrap(errors.New("PushSGXData: Configuration pointer is null"), "Config error")
	}

	pushUrl := conf.ScsBaseUrl + "/platforminfo/push"
	log.Debug("PushSGXData: URL: ", pushUrl)

	requestStr := map[string]string{
		"enc_ppid": platformData.Encrypted_PPID,
		"cpu_svn":  platformData.Cpu_svn,
		"pce_svn":  platformData.Pce_svn,
		"pce_id":   platformData.Pce_id,
		"qe_id":    platformData.Qe_id,
		"manifest": platformData.Manifest}

	reqBytes, err := json.Marshal(requestStr)
	if err != nil {
		return false, errors.Wrap(err, "PushSGXData: Marshal error:"+err.Error())
	}

	req, err := http.NewRequest("POST", pushUrl, bytes.NewBuffer(reqBytes))
	if err != nil {
		return false, errors.Wrap(err, "PushSGXData: Failed to Get New request")
	}

	req.Header.Set("Content-Type", "application/json")
	err = utils.AddJWTToken(req)
	if err != nil {
		return false, errors.Wrap(err, "PushSGXData: Failed to add JWT token to the authorization header")
	}

	resp, err := client.Do(req)
	if resp != nil && resp.StatusCode == http.StatusUnauthorized {
		// fetch token and try again
		utils.AasRWLock.Lock()
		err = utils.AasClient.FetchAllTokens()
		if err != nil {
			return false, errors.Wrap(err, "PushSGXData: FetchAllTokens() Could not fetch token")
		}
		utils.AasRWLock.Unlock()
		err = utils.AddJWTToken(req)
		if err != nil {
			return false, errors.Wrap(err, "PushSGXData: Failed to add JWT token to the authorization header")
		}

		req.Body = ioutil.NopCloser(bytes.NewBuffer(reqBytes))
		resp, err = client.Do(req)
	}

	var retries int = 0
	var time_bw_calls int = conf.WaitTime

	if err != nil || (resp != nil && resp.StatusCode >= http.StatusInternalServerError) {

		for {
			log.Errorf("Retrying for '%d'th time: ", retries)
			req.Body = ioutil.NopCloser(bytes.NewBuffer(reqBytes))
			resp, err = client.Do(req)

			if resp != nil && resp.StatusCode < http.StatusInternalServerError {
				log.Info("PushSGXData: Status code received: " + strconv.Itoa(resp.StatusCode))
				log.Debug("PushSGXData: Retry count now: " + strconv.Itoa(retries))
				break
			}

			if err != nil {
				log.WithError(err).Info("PushSGXData:")
			}

			if resp != nil {
				log.Error("PushSGXData: Invalid status code received: " + strconv.Itoa(resp.StatusCode))
			}

			retries += 1
			if retries >= conf.RetryCount {
				log.Errorf("PushSGXData: Retried %d times, Sleeping %d minutes...", conf.RetryCount, time_bw_calls)
				time.Sleep(time.Duration(time_bw_calls) * time.Minute)
				retries = 0
			}
		}
	}

	if resp != nil && resp.StatusCode != http.StatusCreated && resp.StatusCode != http.StatusOK {
		err = resp.Body.Close()
		if err != nil {
			log.WithError(err).Error("Error closing response")
		}
		return false, errors.New("PushSGXData: Invalid status code received: " + strconv.Itoa(resp.StatusCode))
	}

	var pushResponse SCSPushResponse

	dec := json.NewDecoder(resp.Body)
	dec.DisallowUnknownFields()

	err = dec.Decode(&pushResponse)
	if err != nil {
		return false, errors.Wrap(err, "PushSGXData: Read Response failed")
	}

	log.Debug("PushSGXData: Received SCS Response Data: ", pushResponse)
	err = resp.Body.Close()
	if err != nil {
		log.WithError(err).Error("Error closing response")
	}
	return true, nil
}
