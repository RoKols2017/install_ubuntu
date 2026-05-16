[← Server Security](01-server-security.md) · [Back to README](../README.md)

# SSH-ключи для GitHub и Ubuntu/VPS

Этот документ описывает практичный стандарт SSH-ключей для рабочих машин, GitHub, VPS/root доступа, deploy-пользователей и резервного доступа.

## Где выполнять команды

- Генерация ключей выполняется на клиентской машине: ноутбук, desktop, mini PC или CI/deploy host.
- На сервер копируется только публичный ключ `.pub`.
- Приватный ключ без `.pub` никогда не копируется в GitHub, чаты, тикеты, репозитории или документацию.

Для интерактивной настройки используйте:

```bash
bash scripts/01-setup-ssh-keys.sh
```

## Стандарт именования

Формат:

```text
~/.ssh/<purpose>_<account-or-server>_<device>
```

Примеры:

```text
~/.ssh/github_rokolslab_ubuntu_pc
~/.ssh/github_rokols2017_thinkpad
~/.ssh/vps-fi-01_root_ubuntu_pc
~/.ssh/prod-n8n_deploy_mini_pc
```

## Стандарт комментария

Формат:

```text
email | purpose | account/server | device | date
```

Пример:

```text
rokols2017@gmail.com | github | rokolslab | ubuntu-pc | 2026-05-16
```

## Passphrase policy

- Для GitHub, root/admin и резервных ключей используйте passphrase.
- Для deploy/automation ключей пустая passphrase допустима только после явного принятия риска.
- Если ключ без passphrase скомпрометирован, его нужно сразу удалить из GitHub/VPS и заменить новым.

## Базовые права

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
touch ~/.ssh/config
chmod 600 ~/.ssh/config
```

Для ключей:

```bash
chmod 600 ~/.ssh/github_rokolslab_ubuntu_pc
chmod 644 ~/.ssh/github_rokolslab_ubuntu_pc.pub
```

## GitHub key

Сгенерируйте ключ на клиентской машине:

```bash
ssh-keygen -t ed25519 \
  -f ~/.ssh/github_rokolslab_ubuntu_pc \
  -C "rokols2017@gmail.com | github | rokolslab | ubuntu-pc | 2026-05-16"
```

Покажите публичный ключ:

```bash
cat ~/.ssh/github_rokolslab_ubuntu_pc.pub
```

Добавьте именно `.pub` в GitHub: `Settings` → `SSH and GPG keys` → `New SSH key`.

Для одного GitHub-аккаунта:

```sshconfig
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/github_rokolslab_ubuntu_pc
    IdentitiesOnly yes
```

Для нескольких GitHub-аккаунтов используйте aliases:

```sshconfig
Host github-rokolslab
    HostName github.com
    User git
    IdentityFile ~/.ssh/github_rokolslab_ubuntu_pc
    IdentitiesOnly yes

Host github-rokols2017
    HostName github.com
    User git
    IdentityFile ~/.ssh/github_rokols2017_thinkpad
    IdentitiesOnly yes
```

Проверка:

```bash
ssh -T git@github.com
ssh -T git@github-rokolslab
```

Clone через alias:

```bash
git clone git@github-rokolslab:RoKols2017/install_ubuntu.git
```

## VPS/root key

Сгенерируйте ключ на клиентской машине:

```bash
ssh-keygen -t ed25519 \
  -f ~/.ssh/vps-fi-01_root_ubuntu_pc \
  -C "rokols2017@gmail.com | vps-root | vps-fi-01/root | ubuntu-pc | 2026-05-16"
```

Скопируйте публичный ключ на сервер:

```bash
ssh-copy-id -i ~/.ssh/vps-fi-01_root_ubuntu_pc.pub -p 22 root@SERVER_IP
```

Проверьте вход до hardening:

```bash
ssh -i ~/.ssh/vps-fi-01_root_ubuntu_pc -p 22 root@SERVER_IP
```

Пример alias:

```sshconfig
Host vps-fi-01-root
    HostName SERVER_IP
    User root
    Port 22
    IdentityFile ~/.ssh/vps-fi-01_root_ubuntu_pc
    IdentitiesOnly yes
```

После проверки ключевого доступа можно выполнять hardening и ограничивать root/password login.

## Deploy key

Deploy-ключ используют для отдельного пользователя, например `deploy`, а не для root:

```bash
ssh-keygen -t ed25519 \
  -f ~/.ssh/prod-n8n_deploy_mini_pc \
  -C "ops@example.com | deploy | prod-n8n/deploy | mini-pc | 2026-05-16"
```

Пустая passphrase допустима только для осознанной автоматизации. Ограничьте права пользователя на сервере и ротируйте ключ при смене окружения или команды.

## Backup/rescue key

Резервный ключ нужен для восстановления доступа. Храните его отдельно, используйте passphrase и регулярно проверяйте, что он всё ещё работает.

Если ключ больше не нужен или мог быть скомпрометирован, удалите его из `~/.ssh/authorized_keys` на сервере и из GitHub, если он там использовался.

## Existing key

Существующий ключ можно использовать, если понятны его назначение, где он добавлен и есть ли passphrase. Проверьте права:

```bash
chmod 600 ~/.ssh/existing_private_key
chmod 644 ~/.ssh/existing_private_key.pub
```

Если назначение ключа неизвестно, безопаснее создать новый purpose-specific ключ.

## Ручное добавление на сервер

На сервере добавляйте только публичный ключ:

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
printf '%s\n' 'PASTE_PUBLIC_KEY_HERE' >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

Не вставляйте приватный ключ и не храните его на сервере без явной необходимости.

## Типовые ошибки

`Permission denied (publickey)` для GitHub:

```bash
ssh -vT git@github.com
ssh-add -l
git remote -v
```

Если используется alias, remote должен ссылаться на alias:

```bash
git remote set-url origin git@github-rokolslab:RoKols2017/install_ubuntu.git
```

Для VPS проверьте:

```bash
ssh -i ~/.ssh/vps-fi-01_root_ubuntu_pc -p 22 root@SERVER_IP
```

Если сервер использует другой порт, обновите `Port` в `~/.ssh/config` и UFW rules на сервере.

## Что нельзя делать

- Не копируйте приватные ключи в GitHub, чаты, тикеты, email или репозитории.
- Не добавляйте в GitHub файл без `.pub`.
- Не коммитьте `~/.ssh`, private keys, `.env` и backup secrets.
- Не используйте один ключ для всех сценариев, если доступы можно разделить.
- Не оставляйте старые или скомпрометированные ключи в GitHub и `authorized_keys`.
