# Яндекс КИТ 2014.
## Регистрационные задания. Задание #3.

### Краткая инструкция по настройке
1. Запустите yakit-z01, зайдите под учетной записью toor и выполните команды

        sudo su
        apt-get update
        apt-get install -y curl
        source <(curl -s https://raw.githubusercontent.com/KrylCW/YaKit/master/2014/exam00/task03/step01.sh)
        poweroff

2. Подключите к yakit-z01 LiveCD-образ Debian/Ubuntu, загрузите yakit-z01 в LiveCD-среду и выполните команды
    ```
    sudo su
    source <(curl -s https://raw.githubusercontent.com/KrylCW/YaKit/master/2014/exam00/task03/step02.sh)
    reboot
    ```
3. На yakit-z01 выполните команды
```
sudo su
source <(curl -s https://raw.githubusercontent.com/KrylCW/YaKit/master/2014/exam00/task03/step03.sh)
```
4. Зайдите по http на адрес yakit-z01 и завершите установку Wordpress
5. Измените количество RAM yakit-z03 на 768 МБ, загрузите yakit-z03 и выполните команды
```
sudo sua
apt-get update
apt-get install curl
source <(curl -s https://raw.githubusercontent.com/KrylCW/YaKit/master/2014/exam00/task03/step05.sh)
```
6. На yakit-z01 выполните команды
```
sudo su
source <(curl -s https://raw.githubusercontent.com/KrylCW/YaKit/master/2014/exam00/task03/step06.sh)
```
7. На yakit-z03 выполните команду
```
yandex-tank
```
8. На yakit-z01 выполните команды
```
sudo su
source <(curl -s https://raw.githubusercontent.com/KrylCW/YaKit/master/2014/exam00/task03/step08.sh)
```
9. Повторите шаги 1-3, 6, 8 на yakit-z02
10. На yakit-z03 выполните команды
```
sudo su
source <(curl -s https://raw.githubusercontent.com/KrylCW/YaKit/master/2014/exam00/task03/step10.sh)
```
11. По адресу yakit-z03 по HTTP будет доступен список отчетов yandex-tank'а 