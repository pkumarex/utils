module github.com/flavor-convert

require (
	github.com/antchfx/jsonquery v1.1.4
	github.com/google/uuid v1.2.0
	github.com/intel-secl/intel-secl/v3 v3.5.0
	github.com/stretchr/testify v1.7.0 // indirect
	gopkg.in/yaml.v3 v3.0.0-20210107192922-496545a6307b // indirect
	github.com/vmware/govmomi v0.22.2
)

replace github.com/intel-secl/intel-secl/v3 => github.com/pkumarex/intel-secl/v3 v3.5.1-0.20210331131052-c048288e5d78
replace github.com/vmware/govmomi => github.com/arijit8972/govmomi fix-tpm-attestation-output
