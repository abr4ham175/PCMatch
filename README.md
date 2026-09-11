# PCMatch — aplicación inicial

Esta carpeta contiene una primera interfaz funcional de PCMatch y el esquema de Supabase que soporta el proceso de solicitudes, cotizaciones y contacto protegido.

## Probar ahora

Abre `index.html` en el navegador. Selecciona **Ver como comprador** o **Ver como vendedor**. El modo demostración permite publicar solicitudes, enviar cotizaciones y aceptar una para mostrar el desbloqueo de contacto. Sus datos se conservan solo mientras la página está abierta.

## Conectar Supabase y Google

1. Crea un proyecto en Supabase.
2. En su SQL Editor, ejecuta todo el archivo `supabase-schema.sql`.
3. En Authentication > Providers, activa Google e ingresa el Client ID y Client Secret creados en Google Cloud.
4. Añade el dominio en Authentication > URL Configuration. Para pruebas locales puedes agregar `http://localhost:5500` y la URL final de producción cuando exista.
5. Abre `config.js` y pega la URL y la **publishable key** del proyecto. Ya está enlazado desde `index.html`.
6. Publica estos archivos en un hosting estático. Para una versión de producción, conviene migrar la interfaz a Next.js o React y cargar datos reales desde Supabase.

## Reglas de producto incluidas

- Los vendedores verificados ven solicitudes abiertas, pero no datos de contacto del comprador.
- Las cotizaciones se envían dentro de la aplicación.
- Solo el comprador puede aceptar una cotización.
- La función `accept_quote` registra la aceptación y desbloquea el contacto para ambos participantes.
- Los teléfonos y correos viven en `contact_details`, que no es accesible directamente desde el navegador.
- Un administrador puede verificar o suspender vendedores desde el panel de Supabase durante el MVP.

## Antes de lanzar

- Implementa un formulario de alta de vendedor y verificación manual de RUC/DNI, tienda y garantía.
- Añade límites de cotizaciones por vendedor y reporte/bloqueo de usuarios.
- Prueba las políticas RLS con cuentas separadas de comprador, vendedor y administrador.
- Define términos, privacidad y el mecanismo de resolución de reclamos.
