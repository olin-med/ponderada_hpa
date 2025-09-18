FROM php:8.1-apache

# Instalar extensões necessárias
RUN apt-get update && apt-get install -y \
    htop \
    stress \
    && rm -rf /var/lib/apt/lists/*

# Configurar Apache
RUN a2enmod rewrite

# Copiar arquivos da aplicação
COPY index.php /var/www/html/
COPY stress.php /var/www/html/

# Configurar permissões
RUN chown -R www-data:www-data /var/www/html/
RUN chmod -R 755 /var/www/html/

# Expor porta 80
EXPOSE 80

# Comando para iniciar Apache
CMD ["apache2-foreground"]
