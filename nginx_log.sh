#!/bin/bash

# Путь к файлу для блокировки параллельных запусков скрипта
LOCKFILE="/tmp/lock"

# Путь к файлу с логами веб-сервера/приложения
LOG_FILE="/var/log/nginx/access.log"

# Email адрес, на который будет отправлено письмо
EMAIL="admin@admin.ru"

# Путь к файлу с отчетом
REPORT="/tmp/report.txt"

# Файл, в котором будем хранить последнюю дату обработки логов
LAST_RUN_FILE="/tmp/last_run.txt"

# Определяем последнюю дату обработки логов
if [ -f "$LAST_RUN_FILE" ]; then
  LAST_RUN=$(cat "$LAST_RUN_FILE")
else
  LAST_RUN=$(date --date="-1 hour" "+%d/%b/%Y:%H:%M:%S")
fi

# Текущая дата обработки логов
NOW=$(date "+%d/%b/%Y:%H:%M:%S")

# Проверяем, запущен ли уже скрипт, и если да - завершаем его выполнение
if [ -f "$LOCKFILE" ]; then
    echo "Script is already running."
    exit 1
else
    touch "$LOCKFILE"
fi

# Форматируем файл логов (по умолчанию в access.log поле с временем логов начинается на "[", что мешает отфильтровать по времени с помощью awk )
EDIT_LOG_FILE=/tmp/edit_access.log
sed 's/\[//' $LOG_FILE > $EDIT_LOG_FILE 

# Создаем отчет
echo "Cписок IP адресов с наибольшим количеством запросов:" > $REPORT
awk -v d1="$LAST_RUN" -v d2="$NOW" '$4 > d1 && $4 < d2 {print $1}' $EDIT_LOG_FILE | sort | uniq -c | sort -rn | head -n 10 >> $REPORT

echo "Cписок запрашиваемых URL с наибольшим количеством запросов:" >> $REPORT
awk -v d1="$LAST_RUN" -v d2="$NOW" '$4 > d1 && $4 < d2 {print $7}' "$EDIT_LOG_FILE" | sort | uniq -c | sort -rn | head -n 10 >> $REPORT

echo "Cписок ошибок веб-сервера/приложения:" >> $REPORT
awk -v d1="$LAST_RUN" -v d2="$NOW" '$4 > d1 && $4 < d2 {if ($9 >= 400) {print $9}}' "$EDIT_LOG_FILE" | sort | uniq -c | sort -rn >> $REPORT

echo "Cписок всех кодов HTTP ответа:" >> $REPORT
awk -v d1="$LAST_RUN" -v d2="$NOW" '$4 > d1 && $4 < d2 {print $9}' "$EDIT_LOG_FILE" | sort | uniq -c | sort -rn >> $REPORT

# Отправляем письмо с отчетом
mail -s "Отчет за период с $LAST_RUN по $NOW" "$EMAIL" < "$REPORT" 

# Сохраняем дату последней обработки логов
echo $NOW > $LAST_RUN_FILE

# Удаляем локфайл
rm -f $LOCKFILE
