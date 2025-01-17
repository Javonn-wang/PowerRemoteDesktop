<#-------------------------------------------------------------------------------

    Power Remote Desktop
    Version 1.0 beta 2
    REL: January 2022.

    In loving memory of my father. 
    Thanks for all you've done.
    you will remain in my heart forever.

    .Developer
        Jean-Pierre LESUEUR (@DarkCoderSc)
        https://www.twitter.com/darkcodersc
        https://github.com/DarkCoderSc
        www.phrozen.io
        jplesueur@phrozen.io
        PHROZEN

    .License
        Apache License
        Version 2.0, January 2004
        http://www.apache.org/licenses/

    .Why
        - Prove PowerShell is as "PowerFul" as compiled language.
        - Improve my PowerShell skills.
        - Because Remote Desktop Powershell Scripts doesn't exists so far.        

    .Important
        This PowerShell Application is not yet marked as Stable / Final. It is not recommended to use
        it in a production environment at this time.
        Wait for final 1.0 version.

    .Disclaimer
        We are doing our best to prepare the content of this app. However, PHROZEN SASU and / or
        Jean-Pierre LESUEUR cannot warranty the expressions and suggestions of the contents,
        as well as its accuracy. In addition, to the extent permitted by the law, 
        PHROZEN SASU and / or Jean-Pierre LESUEUR shall not be responsible for any losses
        and/or damages due to the usage of the information on our app.

        By using our app, you hereby consent to our disclaimer and agree to its terms.

        Any links contained in our app may lead to external sites are provided for
        convenience only. Any information or statements that appeared in these sites
        or app are not sponsored, endorsed, or otherwise approved by PHROZEN SASU and / or
        Jean-Pierre LESUEUR. For these external sites, PHROZEN SASU and / or Jean-Pierre LESUEUR
        cannot be held liable for the availability of, or the content located on or through it.
        Plus, any losses or damages occurred from using these contents or the internet
        generally.
        
-------------------------------------------------------------------------------#>

Add-Type -Assembly System.Windows.Forms
Add-Type -Assembly System.Drawing
Add-Type -MemberDefinition '[DllImport("User32.dll")] public static extern bool SetProcessDPIAware();' -Name User32 -Namespace W;

$global:PowerRemoteDesktopVersion = "1.0.4.beta.5"

enum TransportMode {
    Raw = 1
    Base64 = 2
}

function Write-Banner 
{
    <#
        .SYNOPSIS
            Output cool information about current PowerShell module to terminal.
    #>

    Write-Host ""
    Write-Host "Power Remote Desktop Server- Version " -NoNewLine
    Write-Host $global:PowerRemoteDesktopVersion -ForegroundColor Cyan
    Write-Host "Jean-Pierre LESUEUR (" -NoNewLine
    Write-Host "@DarkCoderSc" -NoNewLine -ForegroundColor Green
    Write-Host ") " -NoNewLine
    Write-Host "#" -NoNewLine -ForegroundColor Blue
    Write-Host "#" -NoNewLine -ForegroundColor White
    Write-Host "#" -ForegroundColor Red
    Write-Host "https://" -NoNewLine -ForegroundColor Green
    Write-Host "www.github.com/darkcodersc"
    Write-Host "https://" -NoNewLine -ForegroundColor Green
    Write-Host "www.phrozen.io" 
    Write-Host ""
    Write-Host "License: Apache License (Version 2.0, January 2004)"
    Write-Host "https://" -NoNewLine -ForegroundColor Green
    Write-Host "www.apache.org/licenses/"
    Write-Host ""
}

function Test-PasswordComplexity
{
    <#
        .SYNOPSIS
            Check if password is sufficiently complex.

        .DESCRIPTION
            To return True, Password must follow bellow complexity rules:
                * Minimum 12 Characters.
                * One of following symbols: "!@#%^&*_".
                * At least of lower case character.
                * At least of upper case character. 

        .PARAMETER PasswordCandidate
            The Password to test.
    #>
    param (
        [Parameter(Mandatory=$True)]
        [string] $PasswordCandidate
    )

    $complexityRules = "(?=^.{12,}$)(?=.*[!@#%^&*_]+)(?=.*[a-z])(?=.*[A-Z]).*$"

    return ($PasswordCandidate -match $complexityRules)
}

function New-DefaultX509Certificate
{    
    <#
        .SYNOPSIS
            Generate and install a new self-signed X509 Certificate and install on local machine.

        .DESCRIPTION
            This function is called only if no custom certificate are defined when starting a new Remote
            Desktop Server.

            Important Notice:
                This function requires administrator privileges to enroll / install certificate on local machine.
                If you don't provide your own certificate, you will need to run Remote Desktop Server through an
                elevated PowerShell version.

                You can generate your own certificate using the following OpenSSL commands:
                    * openssl req -x509 -sha512 -nodes -days 365 -newkey rsa:4096 -keyout phrozen.key -out phrozen.crt
                    * openssl pkcs12 -export -out phrozen.p12 -inkey phrozen.key -in phrozen.crt

                Then use the CertificateFile option and use the p12 file.

                You can also export the newly created certificate in Base64 and use it with EncodedCertificate option.
                    * base64 -i phrozen.p12

        .PARAMETER X509_CN
            Certificate Common Name.

        .PARAMETER X509_O
            Certificate Organisation.

        .PARAMETER X509_L
            Certificate Locality (City)

        .PARAMETER X509_S
            Certificate State.

        .PARAMETER X509_C
            Certificate Company Name.

        .PARAMETER X509_OU
            Certificate Organizational Unit.

        .PARAMETER HashAlgorithmName
            Certificate Hash Algorithm.
                Example: SHA128, SHA256, SHA512...

        .PARAMETER CertExpirationInDays
            Certificate Expiration in days.
    #>
    param (
        [string] $X509_CN = "PowerRemoteDesktop.Server",
        [string] $X509_O = "Phrozen",
        [string] $X509_L = "Maisons Laffitte",
        [string] $X509_S = "Yvelines",
        [string] $X509_C = "FR",
        [string] $X509_OU = "Freeware",
        [string] $HashAlgorithmName = "SHA512",
        [int] $CertExpirationInDays = 365
    )

    enum X500NameFlags {
        XCN_CERT_NAME_STR_NONE
        XCN_CERT_SIMPLE_NAME_STR
        XCN_CERT_OID_NAME_STR
        XCN_CERT_X500_NAME_STR
        XCN_CERT_XML_NAME_STR
        XCN_CERT_NAME_STR_SEMICOLON_FLAG
        XCN_CERT_NAME_STR_NO_PLUS_FLAG
        XCN_CERT_NAME_STR_NO_QUOTING_FLAG
        XCN_CERT_NAME_STR_CRLF_FLAG
        XCN_CERT_NAME_STR_COMMA_FLAG
        XCN_CERT_NAME_STR_REVERSE_FLAG
        XCN_CERT_NAME_STR_FORWARD_FLAG
        XCN_CERT_NAME_STR_AMBIGUOUS_SEPARATOR_FLAGS
        XCN_CERT_NAME_STR_DISABLE_IE4_UTF8_FLAG
        XCN_CERT_NAME_STR_ENABLE_T61_UNICODE_FLAG
        XCN_CERT_NAME_STR_ENABLE_UTF8_UNICODE_FLAG
        XCN_CERT_NAME_STR_FORCE_UTF8_DIR_STR_FLAG
        XCN_CERT_NAME_STR_DISABLE_UTF8_DIR_STR_FLAG
        XCN_CERT_NAME_STR_ENABLE_PUNYCODE_FLAG
        XCN_CERT_NAME_STR_DS_ESCAPED
    }

    enum CAPICOM_KEY_SPEC {
        CAPICOM_KEY_SPEC_KEYEXCHANGE = 1
        CAPICOM_KEY_SPEC_SIGNATURE = 2
    }
    
    enum ObjectIdGroupId {
        XCN_CRYPT_ANY_GROUP_ID = 0
        XCN_CRYPT_ENCRYPT_ALG_OID_GROUP_ID = 2
        XCN_CRYPT_ENHKEY_USAGE_OID_GROUP_ID = 7
        XCN_CRYPT_EXT_OR_ATTR_OID_GROUP_ID = 6
        XCN_CRYPT_FIRST_ALG_OID_GROUP_ID = 1
        XCN_CRYPT_GROUP_ID_MASK = 65535
        XCN_CRYPT_HASH_ALG_OID_GROUP_ID = 1
        XCN_CRYPT_KEY_LENGTH_MASK = 268369920
        XCN_CRYPT_LAST_ALG_OID_GROUP_ID = 4
        XCN_CRYPT_LAST_OID_GROUP_ID = 10
        XCN_CRYPT_OID_DISABLE_SEARCH_DS_FLAG = -2147483648
        XCN_CRYPT_OID_INFO_OID_GROUP_BIT_LEN_MASK = 268369920
        XCN_CRYPT_OID_INFO_OID_GROUP_BIT_LEN_SHIFT = 16
        XCN_CRYPT_OID_PREFER_CNG_ALGID_FLAG = 1073741824
        XCN_CRYPT_POLICY_OID_GROUP_ID = 8
        XCN_CRYPT_PUBKEY_ALG_OID_GROUP_ID = 3
        XCN_CRYPT_RDN_ATTR_OID_GROUP_ID = 5
        XCN_CRYPT_SIGN_ALG_OID_GROUP_ID = 4
        XCN_CRYPT_TEMPLATE_OID_GROUP_ID = 9
    }    

    enum X509ContentType {
        Authenticode = 6
        Cert = 1
        Pfx = 3
        Pkcs12 = 3
        Pkcs7 = 5
        SerializedCert = 2
        SerializedStore = 4
        Unknown = 0
    }

    enum X509PrivateKeyExportFlags {
        XCN_NCRYPT_ALLOW_EXPORT_NONE
        XCN_NCRYPT_ALLOW_EXPORT_FLAG
        XCN_NCRYPT_ALLOW_PLAINTEXT_EXPORT_FLAG
        XCN_NCRYPT_ALLOW_ARCHIVING_FLAG
        XCN_NCRYPT_ALLOW_PLAINTEXT_ARCHIVING_FLAG
    }

    enum ObjectIdPublicKeyFlags {
        XCN_CRYPT_OID_INFO_PUBKEY_ANY
        XCN_CRYPT_OID_INFO_PUBKEY_SIGN_KEY_FLAG
        XCN_CRYPT_OID_INFO_PUBKEY_ENCRYPT_KEY_FLAG
    }

    enum X509CertificateEnrollmentContext {
        ContextNone
        ContextUser
        ContextMachine
        ContextAdministratorForceMachine
    }

    enum InstallResponseRestrictionFlags {
        AllowNone
        AllowNoOutstandingRequest
        AllowUntrustedCertificate
        AllowUntrustedRoot
    } 

    enum EncodingType {
        XCN_CRYPT_STRING_BASE64HEADER
        XCN_CRYPT_STRING_BASE64
        XCN_CRYPT_STRING_BINARY
        XCN_CRYPT_STRING_BASE64REQUESTHEADER
        XCN_CRYPT_STRING_HEX
        XCN_CRYPT_STRING_HEXASCII
        XCN_CRYPT_STRING_BASE64_ANY
        XCN_CRYPT_STRING_ANY
        XCN_CRYPT_STRING_HEX_ANY
        XCN_CRYPT_STRING_BASE64X509CRLHEADER
        XCN_CRYPT_STRING_HEXADDR
        XCN_CRYPT_STRING_HEXASCIIADDR
        XCN_CRYPT_STRING_HEXRAW
        XCN_CRYPT_STRING_BASE64URI
        XCN_CRYPT_STRING_ENCODEMASK
        XCN_CRYPT_STRING_CHAIN
        XCN_CRYPT_STRING_TEXT
        XCN_CRYPT_STRING_PERCENTESCAPE
        XCN_CRYPT_STRING_HASHDATA
        XCN_CRYPT_STRING_STRICT
        XCN_CRYPT_STRING_NOCRLF
        XCN_CRYPT_STRING_NOCR
    }

    # Create X.509 Certificate
    $distinguishedName = New-Object -ComObject 'X509Enrollment.CX500DistinguishedName.1'

    # Feel free to edit bellow information with your own.
    $distinguishedName.Encode(
        "CN=${X509_CN},O=${X509_O},L=${X509_L},S=${X509_S},C=${X509_C},OU=${X509_OU}",
        [int][X500NameFlags]::XCN_CERT_NAME_STR_NONE
    )

    # Generate new Private Key    
    $privateKey = New-Object -ComObject 'X509Enrollment.CX509PrivateKey.1'
    $privateKey.ProviderName = "Microsoft RSA SChannel Cryptographic Provider"  

    $privateKey.ExportPolicy = [int][X509PrivateKeyExportFlags]::XCN_NCRYPT_ALLOW_PLAINTEXT_EXPORT_FLAG
    $privateKey.KeySpec = [int][CAPICOM_KEY_SPEC]::CAPICOM_KEY_SPEC_KEYEXCHANGE
    $privateKey.Length = 4096
    $privateKey.MachineContext = $true

    $privateKey.Create()

    # Create Hash Algorithm Object
    $hashAlgorithm = New-Object -ComObject 'X509Enrollment.CObjectId.1'
    $hashAlgorithm.InitializeFromAlgorithmName(
        [int][ObjectIdGroupId]::XCN_CRYPT_FIRST_ALG_OID_GROUP_ID,
        [int][ObjectIdGroupId]::XCN_CRYPT_ANY_GROUP_ID,
        [int][ObjectIdPublicKeyFlags]::XCN_CRYPT_OID_INFO_PUBKEY_ANY,
        $HashAlgorithmName
    )
    
    # Generate Certificate
    $certificate = New-Object -ComObject 'X509Enrollment.CX509CertificateRequestCertificate.1'

    $certificate.InitializeFromPrivateKey(
        [int][X509CertificateEnrollmentContext]::ContextAdministratorForceMachine,
        $privateKey,
        ""
    )

    $certificate.Subject = $distinguishedName     
    $certificate.Issuer = $distinguishedName     

    $certificate.HashAlgorithm = $hashAlgorithm

    $certificate.NotBefore = [DateTime]::Now.AddDays(-1)
    $certificate.NotAfter = [DateTime]::Now.AddDays($CertExpirationInDays)

    $certificate.Encode()

    # Enroll
    $enroll = New-Object -ComObject 'X509Enrollment.CX509Enrollment.1'
    $enroll.InitializeFromRequest($certificate)
    $enroll.CertificateFriendlyName = "Phrozen, PowerRemoteDesktop Server"

    $certificateContent = $enroll.CreateRequest()

    # Install Certificate
    $Enroll.InstallResponse(
        [int][InstallResponseRestrictionFlags]::AllowUntrustedCertificate,
        $certificateContent,
        [int][EncodingType]::XCN_CRYPT_STRING_BASE64,
        "" # No password
    )   
}

function Get-X509CertificateFromStore
{
    <#
        .SYNOPSIS
            Retrieve a X509 Certificate from local machine certificate store using its Subject Name.

        .DESCRIPTION
            Notice, as for generating a new self-signed certificate. This function requires an administrator
            privilege to recover the complete certificate (including the private key).

            It then needs to be run inside an elevated PowerShell session.

            To avoid this issue, as for generating a self-signed certificate, you must provide your own
            certificate when starting a new Remote Desktop Server.

        .PARAMETER SubjectName
            The certificate Subject Name to retrieve from local machine certificate store.

        .EXAMPLE
            Get-X509CertificateFromStore -SubjectName "PowerRemoteDesktop.Server"
    #>
    param (
        [string] $SubjectName = "PowerRemoteDesktop.Server"
    )

    enum StoreLocation {
        CurrentUser = 1
        LocalMachine = 2
    }

    enum OpenFlags {
        IncludeArchived = 8
        MaxAllowed = 2
        OpenExistingOnly = 4
        ReadOnly = 0
        ReadWrite = 1
    }

    enum StoreName {
        AddressBook = 1
        AuthRoot = 2
        CertificateAuthority = 3
        Disallowed = 4
        My = 5
        Root = 6
        TrustedPeople = 7
        TrustedPublisher = 8
    }

    enum X509FindType {
        FindByApplicationPolicy = 10
        FindByCertificatePolicy = 11
        FindByExtension = 12
        FindByIssuerDistinguishedName = 4
        FindByIssuerName = 3
        FindByKeyUsage = 13
        FindBySerialNumber = 5
        FindBySubjectDistinguishedName = 2
        FindBySubjectKeyIdentifier = 14
        FindBySubjectName = 1
        FindByTemplateName = 9
        FindByThumbprint = 0
        FindByTimeExpired = 8
        FindByTimeNotYetValid = 7
        FindByTimeValid = 6
    }

    $store = New-Object System.Security.Cryptography.X509Certificates.X509Store(
        [StoreName]::My,
        [StoreLocation]::LocalMachine
    )

    $store.Open([OpenFlags]::ReadOnly)
    try
    {
        $certCollection = $store.Certificates

        return $certCollection.Find(
            [X509FindType]::FindBySubjectName,
             $SubjectName,
             $false
        )[0]        
    }
    finally
    {
        $store.Close()   
    }
}

function Get-SHA512FromString
{
    <#
        .SYNOPSIS
            Return the SHA512 value from string.

        .PARAMETER String
            A String to hash.

        .EXAMPLE
            Get-SHA512FromString -String "Hello, World"
    #>
    param (
        [Parameter(Mandatory=$True)]
        [string] $String
    )

    $buffer = [IO.MemoryStream]::new([byte[]][char[]]$String)

    return (Get-FileHash -InputStream $buffer -Algorithm SHA512).Hash
}

function Resolve-AuthenticationChallenge
{
    <#
        .SYNOPSIS
            Algorithm to solve the server challenge during password authentication.
        
        .DESCRIPTION
            Server needs to resolve the challenge and keep the solution in memory before sending
            the candidate to remote peer.

        .PARAMETER Password
            Registered password string for server authentication.

        .PARAMETER Candidate
            Random string used to solve the challenge. This string is public and is set across network by server.
            Each time a new connection is requested to server, a new candidate is generated.

        .EXAMPLE
            Resolve-AuthenticationChallenge -Password "s3cr3t!" -Candidate "rKcjdh154@]=Ldc"
    #>
    param (        
       [Parameter(Mandatory=$True)]
       [string] $Password, 

       [Parameter(Mandatory=$True)]
       [string] $Candidate
    )

    $solution = -join($Candidate, ":", $Password)

    for ([int] $i = 0; $i -le 1000; $i++)
    {
        $solution = Get-SHA512FromString -String $solution
    }

    return $solution
}

function Get-LocalMachineInformation
{
    <#
        .SYNOPSIS
            Generate an object containing few useful information about current machine.

        .DESCRIPTION
            Most important part is the target screen information. Without this information, remote viewer
            will not be able to correctly draw / adjust desktop image and simulate mouse events.

            This function is expected to be progressively updated with new required session information.        
    #>
    
    $screens = @()

    $i = 0
    foreach ($screen in ([System.Windows.Forms.Screen]::AllScreens | Sort-Object -Property Primary -Descending))
    {
        $i++

        $screens += New-Object -TypeName PSCustomObject -Property @{
            Id = $i
            Name = $screen.DeviceName
            Primary = $screen.Primary
            Width = $screen.Bounds.Width
            Height = $screen.Bounds.Height
            X = $screen.Bounds.X 
            Y = $screen.Bounds.Y
        }
    }

    return New-Object PSCustomObject -Property @{    
        MachineName = [Environment]::MachineName
        Username = [Environment]::UserName
        WindowsVersion = [Environment]::OSVersion.VersionString
        Screens = ($screens)
    }
}

class ServerSession {
    <#
        .SYNOPSIS
            PowerRemoteDesktop Session Class.
    #>    

    [string] $Id = ""
    [string] $TiedAddress = ""
    [string] $Screen = ""

    ServerSession([string] $RemoteAddress) {
        <#
            .SYNOPSIS
                Create a new session.

            .PARAMETER RemoteAddress
                IP Address to be tied with session and avoid session impersonation outside of the
                network.
        #>

        $this.Id = (SHA512FromString -String (-join ((33..126) | Get-Random -Count 128 | ForEach-Object{[char] $_})))
        $this.TiedAddress = $RemoteAddress        
    }

    [bool] CompareWith([string] $Id, [string] $RemoteAddress) {
        return ($this.Id -eq $Id) -and ($this.TiedAddress -eq $RemoteAddress)
    }
}

class ClientIO {
    <#
        .SYNOPSIS
            Extended version of TcpClient that automatically creates and releases
            required streams with other useful methods.

            Supports SSL/TLS.
    #>    
    [System.Net.Sockets.TcpClient] $Client = $null
    [System.IO.StreamWriter] $Writer = $null
    [System.IO.StreamReader] $Reader = $null
    [System.Net.Security.SslStream] $SSLStream = $null  
    [TransportMode] $TransportMode = "Raw"  


    ClientIO(
        [System.Net.Sockets.TcpClient] $Client,
        [System.Security.Cryptography.X509Certificates.X509Certificate2] $Certificate,
        [bool] $TLSv1_3,
        [TransportMode] $TransportMode
    ) {
        <#
            .SYNOPSIS
                Class constructor.

            .PARAMETER Client
                TcpClient instance returned by listener.

            .PARAMETER Certificate
                X509 Certificate used for SSL/TLS encryption tunnel.

            .PARAMETER TLSv1_3
                Define whether or not SSL/TLS v1.3 must be used.

            .PARAMETER TransportMode
                Define transport method for streams (Base64 or Raw)
        #>

        if ((-not $Client) -or (-not $Certificate))
        {
            throw "ClientIO Class requires both a valid TcpClient and X509Certificate2."
        }
        
        $this.Client = $Client
        $this.TransportMode = $TransportMode

        Write-Verbose "Create new SSL Stream..."

        $this.SSLStream = New-Object System.Net.Security.SslStream($this.Client.GetStream(), $false)                

        if ($TLSv1_3)
        {
            $TLSVersion = [System.Security.Authentication.SslProtocols]::TLS13
        }
        else {
            $TLSVersion = [System.Security.Authentication.SslProtocols]::TLS12
        }

        Write-Verbose "Authenticate as server using ${TLSVersion}..."

        $this.SSLStream.AuthenticateAsServer(
            $Certificate,
            $false,
            $TLSVersion,
            $false
        )

        if (-not $this.SSLStream.IsEncrypted)
        {
            throw "Could not established an encrypted tunnel with remote peer."
        }

        Write-Verbose "Open communication channels..."

        $this.Writer = New-Object System.IO.StreamWriter($this.SSLStream)
        $this.Writer.AutoFlush = $true

        $this.Reader = New-Object System.IO.StreamReader($this.SSLStream)      

        Write-Verbose "Connection ready for use."  
    }

    [bool]Authentify([string] $Password) {
        <#
            .SYNOPSIS
                Handle authentication process with remote peer.

            .PARAMETER Password
                Password used to validate challenge and grant access for a new Client.

            .EXAMPLE
                .Authentify("s3cr3t!")
        #>        
        try
        { 
            if (-not $Password) { 
                throw "During client authentication, a password cannot be blank."
            }

            Write-Verbose "New authentication challenge..."

            $candidate = (-join ((33..126) | Get-Random -Count 128 | ForEach-Object{[char] $_}))
            $candidate = Get-SHA512FromString -String $candidate

            $challengeSolution = Resolve-AuthenticationChallenge -Candidate $candidate -Password $Password   

            Write-Verbose "@Challenge:"
            Write-Verbose "Candidate: ""${candidate}"""
            Write-Verbose "Solution: ""${challengeSolution}"""  
            Write-Verbose "---"

            $this.Writer.WriteLine($candidate)

            Write-Verbose "Candidate sent to client, waiting for answer..."

            $challengeReply = $this.Reader.ReadLine()

            Write-Verbose "Replied solution: ""${challengeReply}"""

            # Challenge solution is a Sha512 Hash so comparison doesn't need to be sensitive (-ceq or -cne)
            if ($challengeReply -ne $challengeSolution)
            {            
                $this.Writer.WriteLine("KO.")

                throw "Client challenge solution does not match our solution."
            }
            else
            {            
                $this.Writer.WriteLine("OK.")

                Write-Verbose "Password Authentication Success"

                return 280121 # True
            }
        }
        catch 
        {
            throw "Password Authentication Failed. Reason: `r`n $($_)"
        }
    }
    
    [void]Hello([ServerSession] $Session) {
        <#
            .SYNOPSIS
                This method is called if a sessio

            .PARAMETER Session
                A ServerSession Object Containing Viewer Sesion Information.            
        #>

        Write-Verbose "Session authentication with remote peer..."
        try 
        {
            $receivedSessionId = $this.Reader.ReadLine()

            Write-Verbose "Peer Session Id: ${receivedSessionId}."

            if ($Session.CompareWith($receivedSessionId, $this.RemoteAddress()))
            {            
                $this.Writer.WriteLine("HELLO.")

                Write-Verbose "Session authentication successful."
            }
            else
            {
                $this.Writer.WriteLine("BYE.")

                throw "Session authentication failed."
            }
        }
        catch
        {
            throw "Session Authentication Failed with extended error: `r`n $($_)"
        }
    }

    [ServerSession]Hello() {
        <#
            .SYNOPSIS
                Initialize a new session with remote Viewer.
        #>

        Write-Verbose "Open a new session with remote peer..."

        $session = [ServerSession]::New($this.RemoteAddress())

        Write-Verbose "@Session"
        Write-Verbose "Id: ""$($session.Id)"""
        Write-Verbose "Addr: ""$($session.TiedAddress)"""
        Write-Verbose "---"

        $sessionInformation = Get-LocalMachineInformation

        $sessionInformation | Add-Member -MemberType NoteProperty -Name "TransportMode" -Value $this.TransportMode
        $sessionInformation | Add-Member -MemberType NoteProperty -Name "SessionId" -Value $session.Id
        $sessionInformation | Add-Member -MemberType NoteProperty -Name "Version" -Value $global:PowerRemoteDesktopVersion                                

        Write-Verbose "Sending Session Information with Local System Information..."

        $this.Writer.WriteLine(($sessionInformation | ConvertTo-Json -Compress))

        if ($sessionInformation.Screens.Length -gt 1)
        {
            Write-Verbose "Current system have $($sessionInformation.Screens.Length) Screens. Waiting for Remote Viewer to choose which screen to capture."

            $screenName = $this.Reader.ReadLine()

            $session.Screen = $screenName            
        }

        Write-Verbose "Handshake done."

        return $session
    }

    [string]RemoteAddress() {
        <#
            .SYNOPSIS
                Returns the remote address of peer.
        #>
        return $this.Client.Client.RemoteEndPoint.Address
    }

    [void]Close() {    
        <#
            .SYNOPSIS
                Release streams and client.
        #>
        
        if ($this.Writer)
        {
            $this.Writer.Close()
        }

        if ($this.Reader)
        {
            $this.Reader.Close()
        }

        if ($this.Stream)
        {
            $this.Stream.Close()
        }

        if ($this.Client)
        {        
            $this.Client.Close()
        }
    }
}

class ServerIO {
    <#
        .SYNOPSIS
            Extended version of TcpListener.

            Supports SSL/TLS.
    #>

    [string] $ListenAddress = "127.0.0.1"
    [int] $ListenPort = 2801
    [bool] $TLSv1_3 = $false    
    [TransportMode] $TransportMode = "Raw"
    [string] $Password

    [System.Net.Sockets.TcpListener] $Server = $null    
    [System.IO.StreamWriter] $Writer = $null
    [System.IO.StreamReader] $Reader = $null
    [System.Security.Cryptography.X509Certificates.X509Certificate2] $Certificate = $null    

    [ServerSession] $Session = $null

    ServerIO(
        <#
            .SYNOPSIS
                Class constructor.

            .PARAMETER ListenAddress
                Define in which interface to listen.

                127.0.0.1: Listen on localhost only.
                0.0.0.0: Listen on all interfaces. 

            .PARAMETER Password
                Password used to authentify with remote peer.

            .PARAMETER ListenPort
                Define which TCP port to listen for new connection.

            .PARAMETER Certificate
                X509 Certificate used for SSL/TLS encryption tunnel.

            .PARAMETER TLSv1_3
                Define whether or not SSL/TLS v1.3 must be used.

            .PARAMETER TransportMode
                Define transport method for streams (Base64 or Raw)
        #>

        [string] $ListenAddress,
        [int] $ListenPort,
        [string] $Password,
        [TransportMode] $TransportMode,
        [System.Security.Cryptography.X509Certificates.X509Certificate2] $Certificate,
        [bool] $TLSv1_3
    ) {
        # Check again in current class just in case.
        if (-not (Test-PasswordComplexity -PasswordCandidate $Password))
        {
            throw "You must use a complex password for Password Authentication."
        }

        $this.ListenAddress = $ListenAddress
        $this.ListenPort = $ListenPort
        $this.TLSv1_3 = $TLSv1_3
        $this.Password = $Password
        $this.TransportMode = $TransportMode

        if (-not $Certificate)
        {
            Write-Verbose "Custom X509 Certificate not specified."

            $this.Certificate = Get-X509CertificateFromStore        
            if (-not $this.Certificate)
            {
                Write-Verbose "Generate and Install a new local X509 Certificate."

                New-DefaultX509Certificate
                
                Write-verbose "Certificate was successfully installed on local machine. Opening..."

                $this.Certificate = Get-X509CertificateFromStore
                if (-not $this.Certificate)
                {
                    throw "Could not open our new local certificate."
                }
            }
            else
            {
                Write-Verbose "Default X509 Certificate was specified."            
            }
        }
        else
        {
            $this.Certificate = $Certificate
        }

        Write-Verbose "@Certificate:"
        Write-Verbose $this.Certificate
        Write-Verbose "---"
    }

    [void]Listen() {
        <#
            .SYNOPSIS
                Start listening on defined interface:port.
        #>
        Write-Verbose "Listen on ""$($this.ListenAddress):$($this.ListenPort)""..."

        $this.Server = New-Object System.Net.Sockets.TcpListener($this.ListenAddress, $this.ListenPort)   

        $this.Server.Start(2) # We are only waiting for two clients at the same time.

        Write-Verbose "Listening..."
    }

    [ClientIO]PullClient([int]$Timeout) {
        <#
            .SYNOPSIS
                Accept new client and associate this client with a new ClientIO Object.

            .PARAMETER Timeout
                By default AcceptTcpClient() will block current thread until a client connects.
                
                Using Timeout and a cool technique, you can stop waiting for client after a certain amount
                of time (In Milliseconds)

                If Timeout is greater than 0 (Milliseconds) then connection timeout is enabled.
        #>

        Write-Verbose "Pull Request..."

        if ($Timeout -gt 0)
        {
            $socketReadList = [System.Collections.ArrayList]@($this.Server.Server)

            [System.Net.Sockets.Socket]::Select($socketReadList, $null, $null, $Timeout * 1000)

            if (-not $socketReadList.Contains($this.Server.Server))
            {
                throw "Pull client timeout."
            }
        }

        $socket = $this.Server.AcceptTcpClient()          

        $client = [ClientIO]::New(            
            $socket,
            $this.Certificate,
            $this.TLSv1_3,
            $this.TransportMode
        )
        try
        {
            Write-Verbose "New client socket connected: ""$($client.RemoteAddress())"". Proceed password authentication..."            

            # STEP 1 : Authentication
            # When Password Authentication Fail, it throw an exception. But as someone paranoid I also want to be
            # that function returns magic token.
            $authenticated = ($client.Authentify($this.Password) -eq 280121)
            if (-not $authenticated)
            {
                throw "Access Denied."
            }
            
            if ($this.Session)
            {
                # STEP 2 : Session Authentication
                $client.Hello($this.Session)                
            }
            else 
            {
                # STEP 2 : Create new Session                    
                $this.Session = $client.Hello()    
            }                        
        }
        catch
        {
            $this.CloseSession()

            $client.Close()

            throw $_
        }

        return $client
    }

    [void]CloseSession() {
        <#
            Terminate an active Server Session
        #>
        $this.Session = $null
    }

    [void]Close() {
        <#
            .SYNOPSIS
                Stop waiting for new clients (Stop listening)
        #>
        if ($this.Server)
        {
            Write-Verbose "Stop listening."

            $this.Server.Stop()
        }
    }
}

$global:DesktopStreamScriptBlock = {
    <#
        .SYNOPSIS
            Threaded code block to send updates of local desktop to remote peer.

            This code is expected to be run inside a new PowerShell Runspace.

        .PARAMETER syncHash.Param.Client
            A ClientIO Object containing an active connection. This is where, desktop updates will be
            sent over network.     
    #>     

    function Get-DesktopImage {	
        <#
            .SYNOPSIS
                Return a snapshot of primary screen desktop.

            .PARAMETER Screen
                Define target screen to capture (if multiple monitor exists).
                Default is primary screen
        #>
        param (
            [System.Windows.Forms.Screen] $Screen = $null
        )
        try 
        {	
            if (-not $Screen)
            {
                $Screen = [System.Windows.Forms.Screen]::PrimaryScreen
            }            

            $size = New-Object System.Drawing.Size(
                $Screen.Bounds.Size.Width,
                $Screen.Bounds.Size.Height
            )

            $location = New-Object System.Drawing.Point(
                $Screen.Bounds.Location.X,
                $Screen.Bounds.Location.Y
            )

            $bitmap = New-Object System.Drawing.Bitmap($size.Width, $size.Height)
            $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
                        
            $graphics.CopyFromScreen($location, [System.Drawing.Point]::Empty, $size)
            
            return $bitmap
        }        
        catch
        {
            if ($bitmap)
            {
                $bitmap.Dispose()
            }
        }
        finally
        {
            if ($graphics)
            {
                $graphics.Dispose()
            }
        }
    } 

    $imageQuality = 100
    if ($syncHash.Param.ImageQuality -ge 0 -and $syncHash.Param.ImageQuality -lt 100)
    {
        $imageQuality = $syncHash.Param.ImageQuality
    }
    try
    {
        [System.IO.MemoryStream] $oldImageStream = New-Object System.IO.MemoryStream

        $jpegEncoder = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' };

        $encoderParameters = New-Object System.Drawing.Imaging.EncoderParameters(1) 
        $encoderParameters.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, $imageQuality)

        $packetSize = 4096        

        while ($true)
        {           
            try
            {                                                           
                $desktopImage = Get-DesktopImage -Screen $syncHash.Param.Screen                                                                   

                $imageStream = New-Object System.IO.MemoryStream

                $desktopImage.Save($imageStream, $jpegEncoder, $encoderParameters)                             

                $sendUpdate = $true

                # Check both stream size.
                $sendUpdate = ($oldImageStream.Length -ne $imageStream.Length)                

                # If sizes are equal, compare both Fingerprint to confirm finding.
                if (-not $sendUpdate)
                {            
                    $imageStream.position = 0
                    $oldImageStream.position = 0  

                    $md5_1 = (Get-FileHash -InputStream $imageStream -Algorithm MD5).Hash   
                    $md5_2 = (Get-FileHash -InputStream $oldImageStream -Algorithm MD5).Hash                   

                    $sendUpdate = ($md5_1 -ne $md5_2)                 
                }

                if ($sendUpdate)
                {                    
                    $imageStream.position = 0 
                    try 
                    {
                        switch ($syncHash.Param.Client.TransportMode)
                        {
                            "Raw"
                            {
                                $syncHash.Param.Client.SSLStream.Write([BitConverter]::GetBytes([int32] $imageStream.Length) , 0, 4) # SizeOf(Int32)                        

                                $totalBytesSent = 0

                                $buffer = New-Object -TypeName byte[] -ArgumentList $packetSize
                                do
                                {       
                                    $bufferSize = ($imageStream.Length - $totalBytesSent)
                                    if ($bufferSize -gt $packetSize)
                                    {
                                        $bufferSize = $packetSize
                                    }    
                                    else
                                    {
                                        # Save some memory operations for creating objects.
                                        # Usually, bellow code is call when last chunk is being sent.
                                        $buffer = New-Object -TypeName byte[] -ArgumentList $bufferSize
                                    }                                                    

                                    # (OPTIMIZATION IDEA): Try with BinaryStream to save the need of "byte[]"" buffer.
                                    $null = $imageStream.Read($buffer, 0, $buffer.Length)

                                    $syncHash.Param.Client.SSLStream.Write($buffer, 0, $buffer.Length)

                                    $totalBytesSent += $bufferSize                                                               
                                } until ($totalBytesSent -eq $imageStream.Length)  

                                break
                            }

                            "Base64"
                            {
                                $syncHash.Param.Client.Writer.WriteLine(
                                    [System.Convert]::ToBase64String($imageStream.ToArray())
                                )

                                break
                            }
                        }                                                                    
                    }
                    catch
                    { break }

                    # Update Old Image Stream for Comparison
                    $imageStream.position = 0 

                    $oldImageStream.SetLength(0)

                    $imageStream.CopyTo($oldImageStream)
                }
                else {}              
            }    
            catch 
            { }
            finally
            {
                if ($desktopImage)
                {
                    $desktopImage.Dispose()
                }

                if ($imageStream)
                {
                    $imageStream.Close()
                }
            }
        }
    }
    finally
    {
        if ($oldImageStream)
        {
            $oldImageStream.Close()
        }
    }
}

$global:InputControlScriptBlock = {   
    <#
        .SYNOPSIS
            Threaded code block to receive remote orders (Ex: Keyboard Strokes, Mouse Clicks, Moves etc...)

            This code is expected to be run inside a new PowerShell Runspace.

        .PARAMETER syncHash.Client
            A ClientIO Object containing an active connection. This is where, remote events will be
            received and treated.            
    #>

    Add-Type -MemberDefinition '[DllImport("user32.dll")] public static extern void mouse_event(int flags, int dx, int dy, int cButtons, int info);[DllImport("user32.dll")] public static extern bool SetCursorPos(int X, int Y);' -Name U32 -Namespace W;

    enum MouseFlags {
        MOUSEEVENTF_ABSOLUTE = 0x8000
        MOUSEEVENTF_LEFTDOWN = 0x0002
        MOUSEEVENTF_LEFTUP = 0x0004
        MOUSEEVENTF_MIDDLEDOWN = 0x0020
        MOUSEEVENTF_MIDDLEUP = 0x0040
        MOUSEEVENTF_MOVE = 0x0001
        MOUSEEVENTF_RIGHTDOWN = 0x0008
        MOUSEEVENTF_RIGHTUP = 0x0010
        MOUSEEVENTF_WHEEL = 0x0800
        MOUSEEVENTF_XDOWN = 0x0080
        MOUSEEVENTF_XUP = 0x0100
        MOUSEEVENTF_HWHEEL = 0x01000
    }

    enum InputCommand {
        Keyboard = 0x1
        MouseClickMove = 0x2
        MouseWheel = 0x3
    }

    enum MouseState {
        Up = 0x1
        Down = 0x2
        Move = 0x3
    }

    class KeyboardSim {
        <#
            .SYNOPSIS
                Class to simulate Keyboard Events using a WScript.Shell
                Instance.
        #>
        [System.__ComObject] $WShell = $null

        KeyboardSim () 
        <#
            .SYNOPSIS
                Class constructor
        #>
        {
            $this.WShell = New-Object -ComObject WScript.Shell        
        }

        [void] SendInput([string] $String) 
        {
            <#
                .SYNOPSIS
                    Simulate Keyboard Strokes. It can contain a single char or a complex string.

                .PARAMETER String
                    Char or String to be simulated as pressed.

                .EXAMPLE
                    .SendInput("Hello, World")
                    .SendInput("J")
            #>        

            # Simulate
            $this.WShell.SendKeys($String)
        }
    }
    

    $keyboardSim = [KeyboardSim]::New()

    while ($true)                    
    {       
        try 
        {            
            $jsonCommand = $syncHash.Param.Client.Reader.ReadLine()                        
        }
        catch
        { 
            # ($_ | Out-File "c:\temp\debug.txt")
            
            break 
        }

        if (-not $jsonCommand)
        { break }

        $command = $jsonCommand | ConvertFrom-Json

        if (-not ($command.PSobject.Properties.name -match "Id"))
        { continue }                                             
         
        switch ([InputCommand] $command.Id)
        {
            # Keyboard Input Simulation
            "Keyboard"
            {                    
                if (-not ($command.PSobject.Properties.name -match "Keys"))
                { break }

                $keyboardSim.SendInput($command.Keys)                             
                break  
            }

            # Mouse Move & Click Simulation
            "MouseClickMove"
            {          
                if (-not ($command.PSobject.Properties.name -match "Type"))
                { break }

                switch ([MouseState] $command.Type)
                {
                    # Mouse Down/Up
                    {($_ -eq "Down") -or ($_ -eq "Up")}
                    {
                        [W.U32]::SetCursorPos($command.X, $command.Y)   

                        $down = ($_ -eq "Down")

                        $mouseCode = [int][MouseFlags]::MOUSEEVENTF_LEFTDOWN
                        if (-not $down)
                        {
                            $mouseCode = [int][MouseFlags]::MOUSEEVENTF_LEFTUP
                        }                                            

                        switch($command.Button)
                        {                        
                            "Right"
                            {
                                if ($down)
                                {
                                    $mouseCode = [int][MouseFlags]::MOUSEEVENTF_RIGHTDOWN
                                }
                                else
                                {
                                    $mouseCode = [int][MouseFlags]::MOUSEEVENTF_RIGHTUP
                                }

                                break
                            }      

                            "Middle"                      
                            {
                                if ($down)
                                {
                                    $mouseCode = [int][MouseFlags]::MOUSEEVENTF_MIDDLEDOWN
                                }
                                else
                                {
                                    $mouseCode = [int][MouseFlags]::MOUSEEVENTF_MIDDLEUP
                                }
                            }                            
                        }                     
                        [W.U32]::mouse_event($mouseCode, 0, 0, 0, 0);

                        break
                    }

                    # Mouse Move
                    "Move"
                    {
                        [W.U32]::SetCursorPos($command.X, $command.Y)

                        break
                    }                    
                }                

                break                
            }        

            # Mouse Wheel Simulation
            "MouseWheel" {
                [W.U32]::mouse_event([int][MouseFlags]::MOUSEEVENTF_WHEEL, 0, 0, $command.Delta, 0);

                break
            }    
        }
    }    
}

function New-RunSpace
{
    <#
        .SYNOPSIS
            Create a new PowerShell Runspace.

        .DESCRIPTION
            Notice: the $host variable is used for debugging purpose to write on caller PowerShell
            Terminal.

        .PARAMETER ScriptBlock
            A PowerShell block of code to be evaluated on the new Runspace.

        .PARAMETER Param
            Optional extra parameters to be attached to Runspace.

        .EXAMPLE
            New-RunSpace -Client $newClient -ScriptBlock { Start-Sleep -Seconds 10 }
    #>

    param(
        [Parameter(Mandatory=$True)]
        [ScriptBlock] $ScriptBlock,

        [PSCustomObject] $Param = $null
    )   

    $syncHash = [HashTable]::Synchronized(@{})    
    $syncHash.host = $host # For debugging purpose

    if ($Param)
    {
        $syncHash.Param = $Param
    }

    $runspace = [RunspaceFactory]::CreateRunspace()
    $runspace.ThreadOptions = "ReuseThread"
    $runspace.ApartmentState = "STA"
    $runspace.Open()                   

    $runspace.SessionStateProxy.SetVariable("syncHash", $syncHash) 

    $powershell = [PowerShell]::Create().AddScript($ScriptBlock)

    $powershell.Runspace = $runspace

    $asyncResult = $powershell.BeginInvoke()

    return New-Object PSCustomObject -Property @{
        Runspace = $runspace
        PowerShell = $powershell
        AsyncResult = $asyncResult
    }
}

function Test-Administrator
{
    <#
        .SYNOPSIS
            Return true if current PowerShell is running with Administrator privilege, otherwise return false.
    #>
    $windowsPrincipal = New-Object Security.Principal.WindowsPrincipal(
        [Security.Principal.WindowsIdentity]::GetCurrent()
    )
    
    return $windowsPrincipal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )    
}

function Invoke-RemoteDesktopServer
{
    <#
        .SYNOPSIS
            Start a new Remote Desktop Server.

        .DESCRIPTION
            Notice: Certificate options are evaluated in this order.
                1) CertificateFile.
                2) EncodedCertificate.

        .PARAMETER ListenAddress
            Define in which interface to listen for new viewer.

        .PARAMETER ListenPort
            Define in which port to listen for new viewer.

        .PARAMETER Password
            Define password used during authentication process. 
            (!) Absolutely use a complex password.

            If no password is specified, then a random complex password will be generated
            and printed on terminal.

        .PARAMETER CertificateFile
            A valid X509 Certificate (With Private Key) File. If set, this parameter is prioritize.

        .PARAMETER EncodedCertificate
            A valid X509 Certificate (With Private Key) encoded as a Base64 String.

        .PARAMETER TransportMode
            Tell server how to send desktop image to remote viewer. Best method is Raw Bytes but I decided to keep
            the Base64 transport method as an alternative.

        .PARAMETER TLSv1_3
            Define whether or not TLS v1.3 must be used for communication with Viewer.

        .PARAMETER DisableVerbosity
            Disable verbosity (not recommended)

        .PARAMETER ImageQuality
            JPEG Compression level from 0 to 100
                0 = Lowest quality.
                100 = Highest quality.
    #>

    param (
        [string] $ListenAddress = "0.0.0.0", 
        [int] $ListenPort = 2801,
        [string] $Password = "",

        [string] $CertificateFile = "", # 1
        # Or
        [string] $EncodedCertificate = "", # 2

        [TransportMode] $TransportMode = "Raw",
        [switch] $TLSv1_3,
        
        [switch] $DisableVerbosity,

        [int] $ImageQuality = 100
    )


    [System.Collections.Generic.List[PSCustomObject]]$runspaces = @()

    $oldErrorActionPreference = $ErrorActionPreference
    $oldVerbosePreference = $VerbosePreference    
    try
    {
        $ErrorActionPreference = "stop"

        if (-not $DisableVerbosity)
        {
            $VerbosePreference = "continue"
        }
        else 
        {
            $VerbosePreference = "SilentlyContinue"
        }

        Write-Banner    

        $null = [W.User32]::SetProcessDPIAware()

        if (-not (Test-Administrator) -and -not $CertificateFile -and -not $EncodedCertificate)
        {
            throw "Insuficient Privilege`r`n`
            When a custom X509 Certificate is not specified, server will generate and install a default one on local machine store.`r`n`
            This operation requires Administrator Privilege.`r`n`
            Specify your own X509 Certificate or run the server in a elevated prompt."
        }

        if ($CertificateFile)
        {
            # TODO: Test if certificate is well-formed.

            if (-not (Test-Path -Path $CertificateFile))
            {            
                throw "Certificate file not found at location: ""${CertificateFile}""."
            }
        }

        if (-not $Password)
        {
            $Password = (
                # a-Z, 0-9, !@#%^&*_
                -join ((48..57) + (64..90) + 35 + (37..38) + 33 + 42 + 94 + 95 + (97..122) | Get-Random -Count 18 | ForEach-Object{[char] $_})
            )
            
            Write-Host -NoNewLine "Server password: """
            Write-Host -NoNewLine ${Password} -ForegroundColor green
            Write-Host """."
        }    
        else 
        {
            if (-not (Test-PasswordComplexity -PasswordCandidate $Password))
            {
                throw "Password complexity is too weak. Please choose a password following following rules:`r`n`
                * Minimum 12 Characters`r`n`
                * One of following symbols: ""!@#%^&*_""`r`n`
                * At least of lower case character`r`n`
                * At least of upper case character`r`n"
            }
        }    

        $Certificate = $null

        if ($CertificateFile -or $EncodedCertificate)
        {
            $Certificate = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
            if ($CertificateFile)
            {
                $Certificate.Import($CertificateFile)
            }
            else
            {
                $Certificate.Import([Convert]::FromBase64String($EncodedCertificate))
            }
        }

        # Create new server and listen
        $server = [ServerIO]::New(
            $ListenAddress,
            $ListenPort,
            $Password,
            $TransportMode,
            $Certificate,
            $TLSv1_3      
        )        

        $server.Listen()        

        while ($true)
        {            
            try
            {                              
                Write-Verbose "Server waiting for new incomming session..."

                # Establish a new Remote Desktop Session.                                    
                $clientDesktop = $server.PullClient(0); 
                
                # Attach to existing session a new handler.
                # An established session is expected to open a new client in the next 10 seconds.
                # Otherwise a Timeout Exception will be raised.
                # Actually, if someone else decide to connect in the mean time it will interrupt the whole session,
                # Remote Viewer will then need to establish a new session from scratch.
                $clientControl = $server.PullClient(10 * 1000);           

                # Grab desired screen to capture
                $screen = [System.Windows.Forms.Screen]::AllScreens | Where-Object -FilterScript { $_.DeviceName -eq $server.Session.Screen }

                # Create Runspace #1 for Desktop Streaming.
                $param = New-Object -TypeName PSCustomObject -Property @{                      
                    Client = $clientDesktop                
                    Screen = $screen
                    ImageQuality = $ImageQuality
                }
                
                $newRunspace = (New-RunSpace -ScriptBlock $global:DesktopStreamScriptBlock -Param $param)                
                $runspaces.Add($newRunspace)

                # Create Runspace #2 for Input Control.
                $param = New-Object -TypeName PSCustomObject -Property @{                      
                    Client = $clientControl                
                }

                $newRunspace = (New-RunSpace -ScriptBlock $global:InputControlScriptBlock -Param $param)                  
                $runspaces.Add($newRunspace)  

                # Waiting for Runspaces to finish their jobs.
                while ($true)
                {
                    # TODO: Inspect TCP Table to probe for ghost connections and gracefully close them.

                    $completed = $true                    
                    
                    # Probe each existing runspaces
                    foreach ($runspace in $runspaces)
                    {
                        if (-not $runspace.AsyncResult.IsCompleted)
                        {
                            $completed = $false

                            break
                        }
                    }

                    if ($completed)
                    { break }

                    Start-Sleep -Seconds 2
                }                                           
            } 
            catch {                
                Write-Output "Viewer Session Exception Raised:"
                Write-Host $_ -ForegroundColor Red
                Write-Output "---"
            }
            finally
            {
                Write-Verbose "Terminate session and close active connections..."
                
                $server.CloseSession()

                if ($clientControl) 
                {
                    $clientControl.Close()
                }

                if ($clientDesktop)
                {
                    $clientDesktop.Close()
                }

                Write-Verbose "Free runspaces..."

                foreach ($runspace in $runspaces)
                {
                    $null = $runspace.PowerShell.EndInvoke($runspace.AsyncResult)
                    $runspace.PowerShell.Runspace.Dispose()                                      
                    $runspace.PowerShell.Dispose()                    
                }    
                $runspaces.Clear()            
            }
        }
    }
    finally
    {    
        if ($server)
        {
            $server.Close()
        }     

        $ErrorActionPreference = $oldErrorActionPreference
        $VerbosePreference = $oldVerbosePreference
    }
}

try {  
    Export-ModuleMember -Function Invoke-RemoteDesktopServer
} catch {}