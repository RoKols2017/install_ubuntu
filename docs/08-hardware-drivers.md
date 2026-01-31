# Драйверы и совместимость железа (GPU/NIC/платы)

Это руководство помогает обеспечить одинаковую работу проекта на VPS и на локальном сервере (bare metal).

## Принципы
1. **CPU‑baseline:** всё работает на CPU без GPU.
2. **GPU‑optional:** GPU включается только при наличии и корректных драйверах.
3. **Фиксация железа:** модель платы и драйверы фиксируются в матрице.

## 1. Сбор информации о железе

### 1.1 Материнская плата и система
```bash
sudo dmidecode -t system -t baseboard
```

### 1.2 PCI‑устройства и драйверы
```bash
lspci -nnk
```

### 1.3 USB‑устройства
```bash
lsusb
```

### 1.4 Сетевые интерфейсы
```bash
ip -br link
sudo lshw -class network -short
```

### 1.5 Версия ядра
```bash
uname -r
```

## 2. GPU‑драйверы

### 2.1 NVIDIA
```bash
ubuntu-drivers devices
sudo ubuntu-drivers install
nvidia-smi
```

### 2.2 AMD/Intel
```bash
sudo apt install -y linux-firmware
lspci -nnk | grep -A3 -i vga
```

## 3. Если установщик не видит сетевой адаптер (новые платы)

### 3.1 Базовые действия после установки
```bash
sudo apt update
sudo apt install -y linux-firmware linux-modules-extra-$(uname -r)
sudo modprobe <driver_module>
dmesg | grep -i firmware
```

### 3.2 Диагностика адаптера
```bash
lspci -nnk | grep -A3 -i ether
ethtool -i <iface>
```

### 3.3 Рекомендации
- Используйте **актуальный ISO Ubuntu Server 24.04.x** (с новым ядром).
- При необходимости подключите временный USB‑Ethernet для установки.
- Зафиксируйте модель NIC и драйвер в матрице совместимости.

## 4. Матрица совместимости (шаблон)

Скопируйте таблицу и заполняйте для каждого сервера.

| Категория | Модель | PCI/USB ID | Драйвер/модуль | Статус | Примечание |
|---|---|---|---|---|---|
| Материнская плата | | | | tested/unknown | |
| NIC | | | | tested/unknown | |
| GPU | | | | tested/unknown | |
| NVMe/SATA | | | | tested/unknown | |

## 5. Что сохранять в репозитории
1. Модель платы и NIC.
2. Версия ядра и модули.
3. Команда установки драйвера (если требуется).

## Источники
- https://ubuntu.com/server/docs/nvidia-drivers
- https://packages.ubuntu.com/noble/linux-firmware
- https://manpages.ubuntu.com/manpages/noble/en/man8/dmidecode.8.html
- https://manpages.ubuntu.com/manpages/noble/en/man8/modprobe.8.html
