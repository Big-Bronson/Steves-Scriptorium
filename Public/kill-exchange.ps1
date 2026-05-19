try {
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction Stop
    Write-Host "Exchange Online session disconnected." -ForegroundColor Green
} catch {
    Write-Host "No active Exchange Online session to disconnect." -ForegroundColor DarkGray
}
