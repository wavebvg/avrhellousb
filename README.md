Это простой GUI под [Lazarus](http://www.lazarus-ide.org/), для тестирования макетной платы [AVR-USB-MEGA16](http://microsin.net/programming/AVR/avr-usb-mega16.html). Является портом проекта [useport](http://www.vanoid.ru/avr/) (инструкцией по подготовке платы можно воспользоваться со страницы оригинального проекта). 

Тестировался только под Linux.

![Картинка](https://github.com/wavebvg/avrhellousb/raw/master/avrhellousb.png)

Зависимости:
1. **libusb-0.1.**

***
sudo apt-get install libusb-0.1-4
***

2. Файл **configs/etc/udev/rules.d/50-usb-microsin.rules** скопировать в **/etc/udev/rules.d/50-usb-microsin.rules**

***
sudo service udev restart
***
