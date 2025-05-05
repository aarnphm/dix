package apiclient

// Instance represents the data structure for a single instance.
type Instance struct {
	ID     string `json:"id"`
	Name   string `json:"name"`
	IP     string `json:"ip,omitempty"` // omitempty in case IP is null or missing
	Status string `json:"status"`
	Region struct {
		Name string `json:"name"`
	} `json:"region"`
	InstanceTypeName string `json:"instance_type_name,omitempty"` // Added for more context
}

// InstancesResponse represents the API response for listing instances.
type InstancesResponse struct {
	Data []Instance `json:"data"`
}

// InstanceType represents the details of a specific instance type.
type InstanceType struct {
	Name        string `json:"name"`
	Description string `json:"description"`
	Specs       struct {
		Vcpus  int `json:"vcpus"`
		MemGiB int `json:"mem_gib"`
		Gpus   int `json:"gpus"`
	} `json:"specs"`
	GpuDescription string `json:"gpu_description"`
}

// Region represents a geographical region.
type Region struct {
	Name string `json:"name"`
}

// InstanceTypeDetails includes the instance type and its availability.
type InstanceTypeDetails struct {
	InstanceType        InstanceType `json:"instance_type"`
	RegionsWithCapacity []Region     `json:"regions_with_capacity_available"`
}

// InstanceTypesResponse represents the API response for listing instance types.
type InstanceTypesResponse struct {
	Data map[string]InstanceTypeDetails `json:"data"`
}

// FileSystem represents a shared filesystem.
type FileSystem struct {
	ID     string `json:"id"`
	Name   string `json:"name"`
	Region struct {
		Name string `json:"name"`
	} `json:"region"`
}

// FileSystemsResponse represents the API response for listing filesystems.
type FileSystemsResponse struct {
	Data []FileSystem `json:"data"`
}

// LaunchRequest represents the payload for launching new instances.
type LaunchRequest struct {
	RegionName       string   `json:"region_name"`
	InstanceTypeName string   `json:"instance_type_name"`
	SSHKeyNames      []string `json:"ssh_key_names"`
	FileSystemNames  []string `json:"file_system_names,omitempty"`
	Name             string   `json:"name"`
	Quantity         int      `json:"quantity,omitempty"` // Defaults to 1 if omitted
}

// LaunchResponse represents the API response after launching instances.
type LaunchResponse struct {
	Data struct {
		InstanceIDs []string `json:"instance_ids"`
	} `json:"data"`
}

// CreateFilesystemRequest represents the payload for creating a filesystem.
type CreateFilesystemRequest struct {
	RegionName string `json:"region"`
	Name       string `json:"name"`
}

// CreateFilesystemResponse represents the API response after creating a filesystem.
type CreateFilesystemResponse struct {
	Data FileSystem `json:"data"` // Assuming the response returns the created filesystem object
}

// TerminateRequest represents the payload for terminating instances.
type TerminateRequest struct {
	InstanceIDs []string `json:"instance_ids"`
}

// TerminateResponse represents the API response after terminating instances.
type TerminateResponse struct {
	Data struct {
		TerminatedInstances []Instance `json:"terminated_instances"` // API likely returns full instance details
	} `json:"data"`
}
