Это простой GUI для тестирования макетной платы [AVR-USB-MEGA16](http://microsin.net/programming/AVR/avr-usb-mega16.html). Написан под [Lazarus](http://www.lazarus-ide.org/) на [FreePascal](https://freepascal.org/). Является портом проекта [useport](http://www.vanoid.ru/avr/) (инструкцией по подготовке платы можно воспользоваться со страницы оригинального проекта). 

Тестировался только под Linux.

![Картинка](https://github.com/wavebvg/avrhellousb/raw/master/avrhellousb.png)

Как собрать и запустить:

1. **libusb-1.0**

***
sudo apt-get install libusb-1.0-0
***

***
sudo ln -s libusb-1.0.so.0.1.0 /lib/x86_64-linux-gnu/libusb-1.0.so
***

2. Файл **configs/etc/udev/rules.d/50-usb-microsin.rules** скопировать в **/etc/udev/rules.d/50-usb-microsin.rules**

***
sudo service udev restart
***

3. Установить **IDE Lazarus**

***
sudo apt-get install lazarus
***

4. Получить исходники

***
git clone https://github.com/wavebvg/avrhellousb.git
git submodule update --init --recursive
***

5. Собрать приложение

Можно воспользоваться IDE или командой

***
lazbuild -B HelloUSB.lpi
***
