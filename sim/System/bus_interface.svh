interface bus_if;
    // AR Channel
    logic [31:0]                ARADDR;
    logic                       ARVALID;
    logic                       ARREADY;
    // R Channel
    logic [127:0]               RDATA;
    logic                       RVALID;
    logic                       RREADY;
    // AW Channel
    logic [31:0]                AWADDR;
    logic                       AWVALID;
    logic                       AWREADY;
    // W Channel
    logic [127:0]               WDATA;
    logic [15:0]                WSTRB;
    logic                       WVALID;
    logic                       WREADY;

    //IO define for those who are master
    modport master_io (
        output  ARADDR,
        output  ARVALID,
        input   ARREADY,
        // R Channel
        input   RDATA,
        input   RVALID,
        output  RREADY,
        // AW Channel
        output  AWADDR,
        output  AWVALID,
        input   AWREADY,
        // W Channel
        output  WDATA,
        output  WSTRB,
        output  WVALID,
        input   WREADY
    );
    
    //IO define for those who are slave
    modport slave_io (
        input   ARADDR,
        input   ARVALID,
        output  ARREADY,
        // R Channel
        output  RDATA,
        output  RVALID,
        input   RREADY,
        // AW Channel
        input   AWADDR,
        input   AWVALID,
        output  AWREADY,
        // W Channel
        input   WDATA,
        input   WSTRB,
        input   WVALID,
        output  WREADY
    );
endinterface //bus_if
