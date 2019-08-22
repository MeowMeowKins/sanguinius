param( [string] $service = $(Throw "Please specify the name of the service with [-service]."), [switch] $email ) 

function send-email($subject,$body,$to)
{
    $SMTPServer = ""
    $SMTPPort = ""
    $Username = ""
    $Password = ""
    $message = New-Object System.Net.Mail.MailMessage
    $message.subject = $subject
    $message.body = $body
    $message.from = ""
    $message.to.add($to)
    $smtp = New-Object System.Net.Mail.SmtpClient($SMTPServer, $SMTPPort);
    $smtp.EnableSSL = $true
    $smtp.Credentials = New-Object System.Net.NetworkCredential($Username, $Password);
    $smtp.Send($message)
}

function send-telegram
{
$Response = Invoke-RestMethod -Uri "https://api.telegram.org/bot$($MyToken)/sendMessage?chat_id=$($chatID)&text=$($body)"
}

$MyToken = ""
$chatID = 
$email = $true
$mailto = ""

if ((Get-Service $service).Status -ne "Running")
{
    $Error.Clear()
    $service
    if ($Error)
    {
        $subject = "[$service] on $env:computername - fatal error."
        $body = "The [$service] service could not be started. The error was:"
        $body += `n+$Error
    }
    else
    {
        Start-Service $service
        $subject = "[$service] on $env:computername - successfully restarted."
        $body ="The [$service] service was found to be stopped on $env:computername and has been started."    
    }
    if  ($email){
        Write-Host $body `n"Sending notifications..."
        $Error.Clear
        send-email -subject $subject -body $body -t ""
        send-telegram
        if (!$Error){
        Write-Host "Notifications sent successfully."
        }
    }
}
else
{
    Write-Host "The [$service] service is running."
}
