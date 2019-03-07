# Manage-Password

平文でパスワード管理したくなかったのと、それをWindowsの標準環境でできるだけ特に何も足さずに実現できる何かが欲しかったので作りました。
概ね、[Powershellで文字列の暗号化と復号化](https://github.com/senkousya/usingEncryptedStandardStringOnPowershell)を参考にしました。というかそのままです。

## 使用法

| オプション | 説明 | 省略時の値 |
| - | - | - | - |
| Environment | 環境名 | 省略不可(Get, Set, Delete指定時のみ) |
| Account | アカウント名 | 省略不可(Get, Set, Delete指定時のみ) |
| Password | パスワード(平文で指定) | 省略不可(Set指定時のみ) |
| Path | パスワード保存ファイルのパス | ~\.idlist |
| MigratePath | 移行用パスワードファイルのパス | ~\Documents\Migrate_IdList.json |
| Key | 移行用パスワードの暗号化キー、byte配列 | 省略不可(Import, Export指定時のみ) |
| Encoding | パスワードファイルの読み込み、保存に使う文字コード | UTF8 |

### パスワードを追加 

環境名、アカウント名、暗号化されたパスワードを一エントリとして、ファイルに保存します。

```PowerShell
Manage-Password.ps1 -Set -Environment <string> -Account <string> -Password <string> [-Path <string>] [-Encoding <string>]
```

### パスワードを取得

環境名、アカウント名を指定して、そのパスワードを取得・復号化し、クリップボードに入れます。

```PowerShell
Manage-Password.ps1 -Get -Environment <string> -Account <string> [-Path <string>] [-Encoding <string>]
```

### 保存した情報を削除

環境名、アカウント名を指定して、そのエントリをファイルから削除します。

```PowerShell
Manage-Password.ps1 -Delete -Environment <string> -Account <string> [-Path <string>] [-Encoding <string>]
```

### 保存した情報を一覧表示

保存されている環境名とアカウント名を一覧表示します。

```PowerShell
Manage-Password.ps1 -List
```

### 移行用ファイルを作成

DPAPIで暗号化されているパスワードファイルから、AESで暗号化されたパスワードファイルを作成します。

```PowerShell
Manage-Password.ps1 -Export -Key <byte[]> [-Path <string>] [-MigratePath <string>] [-Encoding <string>]
```

暗号化キーの作成手順例は以下です(via [AESでの暗号化サンプル](https://github.com/senkousya/usingEncryptedStandardStringOnPowershell/blob/master/readme.md#aes%E3%81%A7%E3%81%AE%E6%9A%97%E5%8F%B7%E5%8C%96%E3%82%B5%E3%83%B3%E3%83%97%E3%83%AB))。

> ```Powershell
> #8*24で192bitのバイト配列を作成
> $EncryptedKey = New-Object Byte[] 24
> 
> #RNGCryptoServiceProviderクラスをcreateしてGetBytesメソッドでバイト配列をランダムなデータで埋める。
> [Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($EncryptedKey)
> 
> #作成されたランダムな配列を表示
> $EncryptedKey
> ```

### 移行用ファイルからパスワードファイルを作成

AESで暗号化されたパスワードファイルから、DPAPIで暗号化されているパスワードファイルを作成します。

```PowerShell
Manage-Password.ps1 -Import -Key <byte[]> [-Path <string>] [-MigratePath <string>] [-Encoding <string>]
```
