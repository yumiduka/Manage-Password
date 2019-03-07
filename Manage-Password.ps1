[CmdletBinding()]
param(
  [Parameter(Mandatory, ParameterSetName='List')][switch]$List,
  [Parameter(Mandatory, ParameterSetName='Get')][switch]$Get,
  [Parameter(Mandatory, ParameterSetName='Set')][switch]$Set,
  [Parameter(Mandatory, ParameterSetName='Delete')][switch]$Delete,
  [Parameter(Mandatory, ParameterSetName='Import')][switch]$Import,
  [Parameter(Mandatory, ParameterSetName='Export')][switch]$Export,
  [Parameter(Mandatory, ParameterSetName='Get')][Parameter(Mandatory, ParameterSetName='Set')][Parameter(Mandatory, ParameterSetName='Delete')][string]$Environment,
  [Parameter(Mandatory, ParameterSetName='Get')][Parameter(Mandatory, ParameterSetName='Set')][Parameter(Mandatory, ParameterSetName='Delete')][string]$Account,
  [Parameter(Mandatory, ParameterSetName='Set')][string]$Password,
  [string]$Path = '~\.idlist',
  [Parameter(ParameterSetName='Import')][Parameter(ParameterSetName='Export')][string]$MigratePath = '~\Documents\Migrate_IdList.json',
  [Parameter(Mandatory, ParameterSetName='Import')][Parameter(Mandatory, ParameterSetName='Export')][Byte[]]$Key,
  [string]$Encoding = 'UTF8'
)

# 関数設定

## 文字列暗号化
function Encryption {
  param(
    [string]$String,
    [byte[]]$Key
  )
  $ErrorActionPreference = 'Stop'

  $SecureString = ConvertTo-SecureString -String $String -AsPlainText -Force

  if ( $Key ) {
    return [string](ConvertFrom-SecureString -SecureString $SecureString -Key $Key)
  } else {
    return [string](ConvertFrom-SecureString -SecureString $SecureString)
  }
}

## 文字列復号化
function Decryption {
  param(
    [string]$String,
    [byte[]]$Key
  )
  $ErrorActionPreference = 'Stop'

  if ( $Key ) {
    $SecureString = ConvertTo-SecureString -String $String -Key $Key
  } else {
    $SecureString = ConvertTo-SecureString -String $String
  }
  return [string]([System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)))
}

## ファイル存在確認(フラグON/OFFである場合とない場合のエラー終了に両対応)
function Test-File {
  param(
    [string]$Path,
    [switch]$IsExist
  )

  if ( $IsExist -and (Test-Path $Path) ) {
    Write-Error ('ファイル "{0}" は存在します。' -f $Path) -Category ObjectNotFound
    exit $false
  } elseif ( ! $IsExist -and ! (Test-Path $Path) ) {
    Write-Error ('ファイル "{0}" が見つかりません。' -f $Path) -Category ObjectNotFound
    exit $false
  }
}

# メイン処理

## パスワードファイル読み込み
$PasswordList = (gc $Path -Encoding $Encoding -ErrorAction SilentlyContinue | ConvertFrom-Json)

## 環境抽出
$Entry = $PasswordList | ? { $_.Environment -eq $Environment -and $_.Account -eq $Account }

switch ( $PsCmdlet.ParameterSetName ) {
  ## キー・ユーザー名列挙
  'List' {
    Test-File $Path
    $PasswordList | select Environment,Account
  }

  ## 復号化した文字列をクリップボードに取得
  'Get' {
    Test-File $Path
    
    if ( ! $Entry ) { 
      Write-Error ('環境 "{0} (ユーザ: {1})" の項目は存在しません。' -f $Environment, $Account) -Category InvalidArgument
      exit $false
    }

    Write-Host ('環境 "{0} (ユーザ: {1})" のパスワードをクリップボードに取得します。' -f $Entry.Environment, $Entry.Account)
    Decryption $Entry.Password | scb
  }

  ## 暗号化した文字列をファイルに追記 
  'Set' {
    if ( $Entry ) {
      Write-Host ('環境 "{0} (ユーザ: {1})" は既に存在します。' -f $Entry.Environment,$Entry.Account)
      if ( (Read-Host '上書きしてもいいですか？(Y/N)') -notmatch "^y(|es)$" ) {
        exit $true
      }
    }

    $PasswordList += [PSCustomObject][Ordered]@{
      Environment = $Environment
      Account = $Account
      Password = Encryption $Password
    }

    $PasswordList | ConvertTo-Json | sc $Path -Encoding UTF8
    $PasswordList | select Environment,Account
  }

  ## 設定した項目を削除
  'Delete' {
    Test-File $Path

    if ( ! $Entry ) { 
      Write-Error ('環境 "{0} (ユーザ: {1})" の項目は存在しません。' -f $Environment, $Account) -Category InvalidArgument
      exit $false
    }

    Write-Host ('環境 "{0} (ユーザ: {1})" を削除します。' -f $Entry.Environment, $Entry.Account)
    if ( (Read-Host '削除してもいいですか？(Y/N)') -notmatch "^y(|es)$" ) {
      exit $true
    }

    $PasswordList = $PasswordList | ? { ! ($_.Environment -eq $Entry.Environment -and $_.Account -eq $Entry.Account) }
    $PasswordList | ConvertTo-Json | sc $Path -Encoding $Encoding
    $PasswordList | select Environment,Account
  }

  ## 移行用パスワードファイルを読み込み、端末用パスワードファイルを作成
  'Import' {
    Test-File $MigratePath
    Test-File $Path -IsExist

    (gc $MigratePath -Encoding $Encoding | ConvertFrom-Json) | % {
      @{
        Environment = $_.Environment
        Account = $_.Account
        Password = Encryption (Decryption $_.Password -Key $Key)
      }
    } | ConvertTo-Json | sc $Path -Encoding $Encoding

    ls $Path
  }

  ## 移行用パスワードファイルを作成
  'Export' {
    Test-File $Path

    $PasswordList | % {
      [Ordered]@{
        Environment = $_.Environment
        Account = $_.Account
        Password = Encryption (Decryption $_.Password) -Key $Key
      }
    } | ConvertTo-Json | sc $MigratePath -Encoding $Encoding

    ls $MigratePath
  }
}
