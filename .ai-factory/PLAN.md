# План улучшения SSH-ключей

Дата создания: 2026-05-16

## Settings

- **Testing:** yes — проверить Bash syntax и, при наличии, ShellCheck.
- **Logging:** standard — сохранить текущие `log_info`, `log_warn`, `log_error`, добавить предупреждения для security-sensitive сценариев.
- **Docs:** yes — обновить README/Quickstart/security docs и добавить подробный SSH-документ.
- **Roadmap Linkage:** none — linkage не выбирался пользователем.

## Краткая оценка текущего состояния

Текущий `scripts/01-setup-ssh-keys.sh` уже полезен как базовый интерактивный сценарий для клиентской машины:

- Скрипт явно предназначен для запуска на клиенте: `scripts/01-setup-ssh-keys.sh:3-4`.
- Используется `ed25519`, что правильно для современного дефолта: `scripts/01-setup-ssh-keys.sh:145`.
- Есть проверка существующего ключа, копирование через `ssh-copy-id`, fallback через ручное добавление в `authorized_keys`, тест SSH-подключения и запись в `~/.ssh/config`.
- В `README.md` и `QUICKSTART.md` уже указано, что SSH-ключи готовятся до hardening.
- В `docs/01-server-security-hardening.md` есть короткий ручной блок по SSH-ключам.

Ограничение текущего состояния: раздел решает в основном один сценарий — ключ для подключения к серверу. Для GitHub, deploy-доступа, резервного доступа, нескольких рабочих машин и нескольких GitHub-аккаунтов логика и документация недостаточно зрелые.

## Проблемы и риски

- `ssh-keygen` вызывается с `-N ""`, то есть пустая passphrase используется всегда и без явного выбора пользователя: `scripts/01-setup-ssh-keys.sh:145`.
- Комментарий ключа сейчас либо email, либо `whoami@hostname`, без purpose, account/server, device и даты: `scripts/01-setup-ssh-keys.sh:136-142`.
- Имя ключа строится как `${server_name}_${client_name}`, без purpose и account/user: `scripts/01-setup-ssh-keys.sh:100-108`.
- Нет отдельного сценария для GitHub: генерация, вывод `.pub`, добавление в GitHub, `ssh -T git@github.com`, `~/.ssh/config`, несколько аккаунтов.
- Нет явного выбора purpose: GitHub, VPS/root, deploy, backup/rescue, existing key.
- Скрипт выводит содержимое публичного ключа, но недостаточно явно предупреждает, что приватный ключ нельзя копировать в GitHub, чаты, тикеты или репозитории.
- `~/.ssh/config` alias сейчас формируется как `${SERVER_NAME}_${CLIENT_NAME}`, что может быть неудобно и конфликтовать с несколькими аккаунтами/серверами: `scripts/01-setup-ssh-keys.sh:338`.
- Документация в `QUICKSTART.md:34-42` слишком короткая: не объясняет сценарии, passphrase, права, GitHub, где выполняются команды.
- `docs/01-server-security-hardening.md:20-42` даёт базовые команды, но не объясняет naming standard, комментарии, `IdentitiesOnly yes`, GitHub aliases и отзыв скомпрометированных ключей.

## Целевой стандарт

Стандарт имени приватного ключа:

```text
~/.ssh/<purpose>_<account-or-server>_<device>
```

Примеры:

```text
~/.ssh/github_rokolslab_ubuntu_pc
~/.ssh/github_rokols2017_thinkpad
~/.ssh/vps-fi-01_root_ubuntu_pc
~/.ssh/prod-n8n_deploy_mini_pc
~/.ssh/backup-vps_root_thinkpad
```

Стандарт комментария ключа:

```text
email | purpose | account/server | device | date
```

Пример:

```text
rokols2017@gmail.com | github | rokolslab | ubuntu-pc | 2026-05-16
```

Целевые сценарии:

- `github` — ключ для GitHub account/org, обычно с passphrase.
- `vps-root` — ключ для первичного root/admin доступа к VPS, passphrase рекомендуется.
- `deploy` — ключ для deploy-пользователя или автоматизации, passphrase зависит от сценария; пустая passphrase только после явного подтверждения риска.
- `backup` или `rescue` — резервный доступ, passphrase рекомендуется, хранить отдельно и документировать отзыв.
- `existing` — использовать уже существующий ключ без генерации.

Passphrase policy:

- Для GitHub и admin/root ключей рекомендовать passphrase.
- Для deploy/automation ключей разрешать пустую passphrase только после явного выбора.
- Не использовать `-N ""` автоматически.
- Если пользователь выбирает пустую passphrase, скрипт должен вывести предупреждение о рисках.

## План изменений по файлам

## Refinement Report

После повторного анализа текущего скрипта и документации план усилен следующими изменениями:

- Добавлена исполнимая task breakdown структура вместо общего списка намерений.
- Уточнены Bash edge cases: безопасное обновление `~/.ssh/config`, отсутствие `sed -i` portability guarantees на macOS, quoting публичного ключа, недопущение дублей в `authorized_keys`.
- Добавлены проверки интерактивных сценариев без выполнения опасных server-mutating команд.
- Добавлена синхронизация `docs/15-scripts-order.md`, потому что он явно описывает `scripts/01-setup-ssh-keys.sh` как клиентский этап установки.
- Уточнено, что реализация не должна пытаться автоматически открыть GitHub UI, использовать GitHub tokens или читать реальные приватные ключи.

## Tasks

### Phase 1 — Script Design And Compatibility

- [x] **Task 1: Зафиксировать сценарии и совместимость текущего server flow**
  - Файлы: `scripts/01-setup-ssh-keys.sh`.
  - Deliverable: в начале `main` добавить выбор сценария: GitHub, VPS/root, deploy, backup/rescue, existing key.
  - Сохранить текущий интерактивный сценарий подключения к серверу как default-compatible path для пользователей, которые запускают скрипт по `QUICKSTART.md`.
  - Logging: `log_step` для выбранного сценария, `log_info` для client host/user, `log_warn` если пользователь выбирает сценарий с повышенным риском.
  - Dependencies: нет.

- [x] **Task 2: Добавить безопасную нормализацию имени ключа**
  - Файлы: `scripts/01-setup-ssh-keys.sh`.
  - Deliverable: заменить текущую пару `generate_key_name(server_name, client_name)` на standard-based генерацию `<purpose>_<account-or-server>_<device>`.
  - Добавить helper `sanitize_component`, который приводит ввод к нижнему регистру, заменяет пробелы на `-` или `_`, удаляет `/`, `..`, quotes, shell metacharacters и пустые компоненты.
  - Edge cases: IP-адреса, FQDN, `root@host`, пробелы в device name, повторяющиеся `_`/`-`.
  - Logging: `log_info` с итоговым именем ключа, без вывода приватного содержимого.
  - Dependencies: Task 1.

- [x] **Task 3: Добавить structured key comment**
  - Файлы: `scripts/01-setup-ssh-keys.sh`.
  - Deliverable: формировать комментарий `email | purpose | account/server | device | date`.
  - Дата должна генерироваться через локальную дату в формате `YYYY-MM-DD`, без требования GNU-specific flags.
  - Если email пустой, использовать нейтральное значение вроде `no-email` или явно запросить email с возможностью пропуска; не придумывать реальные данные.
  - Logging: `log_info` с комментарием допустим, потому что это не secret, но не выводить приватный ключ.
  - Dependencies: Task 2.

### Phase 2 — Key Generation Security

- [x] **Task 4: Переработать passphrase flow**
  - Файлы: `scripts/01-setup-ssh-keys.sh`.
  - Deliverable: убрать автоматическое `ssh-keygen ... -N ""` из default path.
  - Для GitHub, VPS/root и backup/rescue рекомендовать passphrase и запускать `ssh-keygen` без `-N`, чтобы пользователь ввёл passphrase через стандартный OpenSSH prompt.
  - Для deploy/automation разрешить пустую passphrase только после явного подтверждения и предупреждения о рисках.
  - Edge cases: пользователь отменяет генерацию, ключ уже существует, пользователь выбирает existing key.
  - Logging: `log_warn` для empty passphrase, `log_info` для выбранной политики без записи самой passphrase.
  - Dependencies: Task 3.

- [x] **Task 5: Централизовать права файлов SSH**
  - Файлы: `scripts/01-setup-ssh-keys.sh`.
  - Deliverable: добавить `ensure_ssh_dir`/`fix_ssh_permissions` и использовать после генерации, выбора existing key и записи config.
  - Требуемые права: `chmod 700 ~/.ssh`, `chmod 600 ~/.ssh/config`, `chmod 600 private_key`, `chmod 644 public_key`.
  - Не менять права файлов, которых нет; existing private key проверять осторожно и предупреждать, если права слишком широкие.
  - Logging: `log_info` при исправлении прав, `log_warn` если невозможно исправить права.
  - Dependencies: Task 4.

### Phase 3 — Scenario Flows

- [x] **Task 6: Реализовать GitHub flow**
  - Файлы: `scripts/01-setup-ssh-keys.sh`.
  - Deliverable: отдельный сценарий без `ssh-copy-id`, который генерирует/использует GitHub key, выводит только `.pub`, показывает инструкцию добавить ключ в GitHub и предлагает проверку `ssh -T git@github.com` или alias.
  - Добавить поддержку `Host github.com` для default account и `Host github-<account>` для нескольких аккаунтов.
  - В `~/.ssh/config` обязательно писать `HostName github.com`, `User git`, `IdentityFile`, `IdentitiesOnly yes`.
  - Edge cases: уже существующий `Host github.com`, несколько GitHub аккаунтов, пользователь не хочет менять config.
  - Logging: `log_warn`, что в GitHub добавляется только `.pub`; `log_info` с командой проверки.
  - Dependencies: Task 5.

- [x] **Task 7: Улучшить VPS/root, deploy и backup/rescue flows**
  - Файлы: `scripts/01-setup-ssh-keys.sh`.
  - Deliverable: адаптировать текущий server flow под разные purpose: `vps-root`, `deploy`, `backup`/`rescue`.
  - Для server flows оставить `ssh-copy-id`, ручной fallback и test connection.
  - Для deploy flow явно спрашивать user на сервере и не считать `root` дефолтом.
  - Для backup/rescue flow добавить предупреждение о хранении и отзыве ключа.
  - Logging: `log_step` для копирования на сервер, `log_warn` для root/deploy/security decisions.
  - Dependencies: Task 6.

- [x] **Task 8: Сделать обновление `~/.ssh/config` безопаснее**
  - Файлы: `scripts/01-setup-ssh-keys.sh`.
  - Deliverable: вынести запись config в helper, который создаёт backup перед изменением, проверяет существующий `Host` alias и не ломает соседние блоки.
  - Не полагаться бездумно на `sed -i`, потому что поведение отличается на GNU/Linux и macOS; если используется `sed`, делать portable-safe fallback или переписывать через временный файл.
  - Проверять `Host` match как отдельную строку, а не substring.
  - Logging: `log_info` о backup/update, `log_warn` при конфликте alias.
  - Dependencies: Task 6 и Task 7.

- [x] **Task 9: Укрепить ручной fallback для `authorized_keys`**
  - Файлы: `scripts/01-setup-ssh-keys.sh`, `docs/ssh-keys.md`.
  - Deliverable: заменить небезопасно выглядящий manual snippet с `echo` на `printf '%s\n' 'PUBLIC_KEY' >> ~/.ssh/authorized_keys` в документации и выводе скрипта.
  - По возможности для remote command сначала проверять, что public key ещё не добавлен, чтобы не плодить дубли.
  - Не выводить private key; выводить только public key.
  - Logging: `log_warn` при fallback, `log_info` с ручными командами.
  - Dependencies: Task 7.

### Phase 4 — Documentation

- [x] **Task 10: Создать `docs/ssh-keys.md` как основной SSH-key guide**
  - Файлы: `docs/ssh-keys.md`.
  - Deliverable: новый документ с разделами: где выполнять команды, naming standard, comment standard, passphrase policy, GitHub key, VPS/root key, deploy key, backup/rescue key, existing key, `~/.ssh/config`, permissions, troubleshooting, rotation/revoke, запрещённые действия.
  - Включить конкретные команды из раздела “Команды для документации” ниже.
  - Security notes: private key нельзя копировать в GitHub, чаты, тикеты, репозитории; в GitHub добавляется только `.pub`; не коммитить `~/.ssh`, private keys, `.env`; скомпрометированные ключи отзывать.
  - Logging: не применимо к docs, но документация должна описывать ожидаемые предупреждения скрипта.
  - Dependencies: Task 6, Task 7, Task 9.

- [x] **Task 11: Обновить Quick Start и security docs без дублирования подробного guide**
  - Файлы: `README.md`, `QUICKSTART.md`, `docs/01-server-security.md`, `docs/01-server-security-hardening.md`, `docs/15-scripts-order.md`.
  - Deliverable: короткие ссылки на `docs/ssh-keys.md`, явное указание “на клиентской машине”, pre-hardening checklist и минимальный server-side fallback.
  - `README.md` и `QUICKSTART.md` должны оставаться короткими landing/quick path, без копирования всего GitHub guide.
  - `docs/15-scripts-order.md` должен остаться согласованным с тем, что `scripts/01-setup-ssh-keys.sh` запускается на клиентской машине.
  - Logging: не применимо к docs.
  - Dependencies: Task 10.

### Phase 5 — Verification

- [x] **Task 12: Проверить Bash syntax и основные интерактивные ветки**
  - Файлы: `scripts/01-setup-ssh-keys.sh`, `scripts/98-verify-scripts.sh`.
  - Deliverable: `bash scripts/98-verify-scripts.sh` проходит; если ShellCheck установлен, нет новых критичных предупреждений.
  - Добавить ручной QA checklist для сценариев: GitHub default account, GitHub alias account, VPS/root, deploy with empty passphrase confirmation, existing key, config alias conflict.
  - Не выполнять реальные подключения к production VPS и не копировать ключи на сервер без явного подтверждения.
  - Logging: убедиться, что warnings появляются для empty passphrase и private-key safety.
  - Dependencies: Task 1-11.

### `scripts/01-setup-ssh-keys.sh`

- Добавить выбор сценария в начале интерактива: GitHub, VPS/root, deploy, backup/rescue, existing key.
- Сохранить текущий путь “подключение к серверу” как совместимый интерактивный сценарий, но переименовать его внутри логики в `vps-root` или `server`.
- Добавить функцию нормализации `sanitize_component`, чтобы purpose/account/device безопасно попадали в имя файла: lowercase, замена пробелов на `-` или `_`, запрет `/`, `..`, shell metacharacters.
- Изменить `generate_key_name` на стандарт `<purpose>_<account-or-server>_<device>`.
- Добавить генерацию комментария: `email | purpose | account/server | device | date`.
- Добавить интерактивный выбор passphrase: “использовать passphrase?”, “ввести вручную через ssh-keygen prompt?”.
- Не передавать `-N ""`, если пользователь не выбрал пустую passphrase явно.
- Практичный вариант: для passphrase использовать обычный prompt `ssh-keygen`, то есть не передавать `-N`, кроме случая явного empty-passphrase.
- Для explicit empty passphrase использовать `-N ""`, но только после предупреждения и подтверждения.
- Добавить функцию `fix_ssh_permissions`, которая выполняет `chmod 700 ~/.ssh`, `chmod 600 ~/.ssh/config`, `chmod 600 "$key_path"`, `chmod 644 "$key_path.pub"`.
- Добавить GitHub flow без копирования на сервер: сгенерировать ключ, вывести `.pub`, показать URL GitHub settings, предложить `ssh -T git@github.com`.
- Добавить GitHub `~/.ssh/config` entries.
- Для одного GitHub аккаунта использовать `Host github.com` только если пользователь явно выбирает default.
- Для нескольких аккаунтов рекомендовать alias вида `github-rokolslab` и `github-rokols2017`.
- Для server/deploy flow оставить `ssh-copy-id`, ручной fallback и SSH test.
- Добавить предупреждения перед выводом ключа: выводится только публичный ключ `.pub`; приватный ключ не показывать.
- Не усложнять скрипт до enterprise-инсталлятора: оставить один Bash-файл, интерактивные вопросы, без внешних зависимостей кроме OpenSSH tools.

### `README.md`

- В Quick Start заменить короткую строку “Prepare SSH keys from the client machine” на более явную.
- Указать, что `scripts/01-setup-ssh-keys.sh` запускается на рабочей машине, не на сервере.
- Добавить ссылку на подробный документ `docs/ssh-keys.md` или соответствующий раздел security docs.
- Сохранить общий Quick Start компактным.

### `QUICKSTART.md`

- Расширить раздел `## 3. Подготовьте SSH-ключи`.
- Добавить короткое различение: GitHub ключ нужен для работы с репозиториями, VPS/root ключ нужен для входа на сервер, deploy ключ нужен для автоматизации.
- Явно написать: команды генерации выполняются на клиентской машине.
- Перед hardening оставить требование проверить доступ по ключу.
- Добавить минимальную проверку прав `~/.ssh`.
- Добавить ссылку на новый `docs/ssh-keys.md`.

### `docs/01-server-security.md`

- Добавить краткий pre-hardening checklist:
- ключ создан на клиентской машине;
- публичный ключ добавлен в `authorized_keys`;
- вход по ключу проверен во второй SSH-сессии;
- root/password hardening включается только после проверки.
- Сослаться на `docs/ssh-keys.md`.
- Не перегружать этот файл GitHub-деталями.

### `docs/01-server-security-hardening.md`

- Заменить текущий короткий блок `SSH-ключи` на ссылку на `docs/ssh-keys.md` плюс минимальный server-side fallback.
- Оставить команды ручной настройки `authorized_keys`, но добавить предупреждение: вставлять только публичный ключ.
- Уточнить права `~/.ssh` и `authorized_keys`.

### `docs/ssh-keys.md`

- Создать как основной подробный документ.
- Разделы: где выполнять команды, стандарт именования, стандарт комментариев, passphrase policy, GitHub key, VPS/root key, deploy key, backup/rescue key, existing key, `~/.ssh/config`, permissions, типовые ошибки, отзыв и ротация ключей, что никогда не делать.

## Команды для документации

Базовые права:

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
touch ~/.ssh/config
chmod 600 ~/.ssh/config
```

Генерация GitHub-ключа с passphrase prompt:

```bash
ssh-keygen -t ed25519 \
  -f ~/.ssh/github_rokolslab_ubuntu_pc \
  -C "rokols2017@gmail.com | github | rokolslab | ubuntu-pc | 2026-05-16"
```

Показать только публичный ключ:

```bash
cat ~/.ssh/github_rokolslab_ubuntu_pc.pub
```

Права на ключи:

```bash
chmod 600 ~/.ssh/github_rokolslab_ubuntu_pc
chmod 644 ~/.ssh/github_rokolslab_ubuntu_pc.pub
```

GitHub config для одного аккаунта:

```sshconfig
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/github_rokolslab_ubuntu_pc
    IdentitiesOnly yes
```

GitHub config для нескольких аккаунтов:

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

Проверка GitHub:

```bash
ssh -T git@github.com
ssh -T git@github-rokolslab
```

Clone через alias:

```bash
git clone git@github-rokolslab:RoKols2017/install_ubuntu.git
```

Генерация VPS/root ключа:

```bash
ssh-keygen -t ed25519 \
  -f ~/.ssh/vps-fi-01_root_ubuntu_pc \
  -C "rokols2017@gmail.com | vps-root | vps-fi-01/root | ubuntu-pc | 2026-05-16"
```

Копирование на сервер:

```bash
ssh-copy-id -i ~/.ssh/vps-fi-01_root_ubuntu_pc.pub -p 22 root@SERVER_IP
```

Проверка входа:

```bash
ssh -i ~/.ssh/vps-fi-01_root_ubuntu_pc -p 22 root@SERVER_IP
```

Server alias:

```sshconfig
Host vps-fi-01-root
    HostName SERVER_IP
    User root
    Port 22
    IdentityFile ~/.ssh/vps-fi-01_root_ubuntu_pc
    IdentitiesOnly yes
```

Deploy key с явным предупреждением про пустую passphrase:

```bash
ssh-keygen -t ed25519 \
  -f ~/.ssh/prod-n8n_deploy_mini_pc \
  -C "ops@example.com | deploy | prod-n8n/deploy | mini-pc | 2026-05-16"
```

Ручное добавление публичного ключа на сервере:

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
printf '%s\n' 'PASTE_PUBLIC_KEY_HERE' >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

Диагностика GitHub `Permission denied (publickey)`:

```bash
ssh -vT git@github.com
ssh-add -l
git remote -v
```

Проверка remote для alias:

```bash
git remote set-url origin git@github-rokolslab:RoKols2017/install_ubuntu.git
```

## Acceptance Criteria

- Скрипт сохраняет текущий интерактивный VPS/server сценарий и не требует root.
- Скрипт не использует пустую passphrase без явного выбора пользователя.
- Скрипт генерирует имена по стандарту `<purpose>_<account-or-server>_<device>`.
- Скрипт генерирует комментарии по стандарту `email | purpose | account/server | device | date`.
- Скрипт поддерживает минимум сценарии `GitHub`, `VPS/root`, `deploy`, `backup/rescue`, `existing key`.
- Скрипт выставляет права `700` для `~/.ssh`, `600` для private key/config, `644` для public key.
- GitHub flow не пытается копировать ключ на VPS и объясняет, что в GitHub добавляется только `.pub`.
- `~/.ssh/config` содержит `IdentityFile` и `IdentitiesOnly yes`.
- Документация ясно разделяет команды для клиентской машины и команды для сервера.
- `README.md` и `QUICKSTART.md` остаются короткими, но ссылаются на подробный SSH-документ.
- `docs/ssh-keys.md` покрывает GitHub, VPS/root, deploy, backup/rescue, existing key, permissions, troubleshooting и key rotation.
- В документации нет RSA как дефолта.
- В документации нет реальных приватных ключей, токенов или секретов.
- `bash scripts/98-verify-scripts.sh` проходит после реализации.
- При наличии ShellCheck скрипт проходит без предупреждений.

## Что не менять

- Не менять порядок установки: SSH-ключи остаются шагом до `scripts/02-secure-server.sh`.
- Не превращать `scripts/01-setup-ssh-keys.sh` в неинтерактивный enterprise-инсталлятор.
- Не требовать GitHub CLI, API tokens или web automation.
- Не удалять поддержку `ssh-copy-id`.
- Не ломать сценарий существующего ключа.
- Не менять hardening-логику в `scripts/02-secure-server.sh` в рамках этой задачи.
- Не добавлять реальные ключи, `.env`, токены или персональные secrets.
- Не делать RSA дефолтом; `ed25519` оставить основным вариантом.

## Недостающие данные

Реальные имена GitHub-аккаунтов, серверов, deploy-пользователей и рабочих устройств должны вводиться пользователем или оставаться примерами. Их не нужно угадывать в коде или документации.

## Commit Plan

- `docs: plan ssh key management improvements` — сохранить план.
- При реализации: `feat: improve ssh key setup scenarios` — изменения скрипта.
- При реализации: `docs: document ssh key workflows` — документация и ссылки.
