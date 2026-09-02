#!/usr/bin/env bash

set -euo pipefail

BASE_URL="${ESPO_BASE_URL:-http://localhost:8080/api/v1}"
ADMIN_USER="${ESPO_ADMIN_USER:-admin}"
ADMIN_PASSWORD="${ESPO_ADMIN_PASSWORD:?Set ESPO_ADMIN_PASSWORD}"

api_get() {
    curl --fail-with-body --silent --show-error \
        -u "$ADMIN_USER:$ADMIN_PASSWORD" "$1"
}

find_id() {
    local entity="$1"
    local attribute="$2"
    local value="$3"

    curl --fail-with-body --silent --show-error \
        -u "$ADMIN_USER:$ADMIN_PASSWORD" \
        --get \
        --data-urlencode "where[0][type]=equals" \
        --data-urlencode "where[0][attribute]=$attribute" \
        --data-urlencode "where[0][value]=$value" \
        "$BASE_URL/$entity" | jq -r '.list[0].id // empty'
}

ensure_record() {
    local entity="$1"
    local attribute="$2"
    local value="$3"
    local payload="$4"
    local id

    id="$(find_id "$entity" "$attribute" "$value")"

    if [[ -n "$id" ]]; then
        printf 'reused  %-12s %s\n' "$entity" "$value" >&2
        printf '%s' "$id"
        return
    fi

    id="$(curl --fail-with-body --silent --show-error \
        -u "$ADMIN_USER:$ADMIN_PASSWORD" \
        -H 'Content-Type: application/json' \
        -X POST \
        --data "$payload" \
        "$BASE_URL/$entity" | jq -r '.id')"

    if [[ -z "$id" || "$id" == "null" ]]; then
        echo "Could not create $entity: $value" >&2
        exit 1
    fi

    printf 'created %-12s %s\n' "$entity" "$value" >&2
    printf '%s' "$id"
}

echo "Checking EspoCRM..."
api_get "$BASE_URL/App/user" >/dev/null

acme_payload='{
  "name": "ACME Pedidos S.A.C.",
  "type": "Customer",
  "industry": "Wholesale",
  "website": "https://acme-pedidos.example",
  "emailAddress": "contacto@acme-pedidos.example",
  "phoneNumber": "+51 1 555 0100",
  "sicCode": "5149",
  "billingAddressStreet": "Av. Javier Prado Este 1234, Piso 8",
  "billingAddressCity": "San Isidro",
  "billingAddressState": "Lima",
  "billingAddressCountry": "Perú",
  "billingAddressPostalCode": "15036",
  "shippingAddressStreet": "Av. Separadora Industrial 2450, Almacén 4",
  "shippingAddressCity": "Ate",
  "shippingAddressState": "Lima",
  "shippingAddressCountry": "Perú",
  "shippingAddressPostalCode": "15012",
  "description": "Empresa ficticia de demostración dedicada a la gestión, preparación y entrega de pedidos corporativos. RUC demo: 20999999991. Razón social: ACME Pedidos S.A.C. Inicio de operaciones: 15/03/2018. Moneda operativa: PEN y USD. Horario: lunes a viernes de 08:00 a 18:00. Capacidad: 2,500 pedidos mensuales. SLA estándar: 48 horas. Política de calidad: trazabilidad completa desde la cotización hasta la entrega."
}'
acme_id="$(ensure_record Account name 'ACME Pedidos S.A.C.' "$acme_payload")"

while IFS= read -r row; do
    name="$(jq -r '.name' <<<"$row")"
    payload="$(jq -c '{name, description}' <<<"$row")"
    ensure_record Team name "$name" "$payload" >/dev/null
done <<'JSON'
{"name":"ACME | Dirección General","description":"Gobierno corporativo, estrategia y control ejecutivo de ACME Pedidos S.A.C."}
{"name":"ACME | Ventas","description":"Prospección, gestión de cuentas, cotizaciones y cierre de pedidos."}
{"name":"ACME | Operaciones","description":"Planificación, preparación y control de calidad de pedidos."}
{"name":"ACME | Logística","description":"Almacén, transporte, distribución y trazabilidad de entregas."}
{"name":"ACME | Finanzas","description":"Facturación, cobranzas, tesorería y control presupuestal."}
{"name":"ACME | Servicio al Cliente","description":"Postventa, incidencias, devoluciones y medición de satisfacción."}
{"name":"ACME | Tecnología","description":"Plataformas, integraciones, seguridad y soporte interno."}
{"name":"ACME | Recursos Humanos","description":"Selección, bienestar, capacitación y administración de personal."}
JSON

while IFS= read -r row; do
    username="$(jq -r '.userName' <<<"$row")"
    department="$(jq -r '.department' <<<"$row")"
    team_id="$(find_id Team name "ACME | $department")"
    payload="$(jq -c \
        --arg teamId "$team_id" \
        'del(.department) + {
          type: "regular",
          isActive: true,
          password: "AcmeDemo2026!",
          passwordConfirm: "AcmeDemo2026!",
          sendAccessInfo: false,
          defaultTeamId: $teamId,
          teamsIds: [$teamId]
        }' <<<"$row")"
    ensure_record User userName "$username" "$payload" >/dev/null
done <<'JSON'
{"userName":"andrea.torres","firstName":"Andrea","lastName":"Torres Salazar","title":"Gerente General","gender":"Female","emailAddress":"andrea.torres@acme-pedidos.example","phoneNumber":"+51 1 555 0101","department":"Dirección General"}
{"userName":"luis.mendoza","firstName":"Luis","lastName":"Mendoza Ríos","title":"Director Comercial","gender":"Male","emailAddress":"luis.mendoza@acme-pedidos.example","phoneNumber":"+51 1 555 0102","department":"Ventas"}
{"userName":"mateo.silva","firstName":"Mateo","lastName":"Silva Paredes","title":"Ejecutivo de Cuentas Senior","gender":"Male","emailAddress":"mateo.silva@acme-pedidos.example","phoneNumber":"+51 1 555 0103","department":"Ventas"}
{"userName":"camila.rojas","firstName":"Camila","lastName":"Rojas Vega","title":"Jefa de Operaciones","gender":"Female","emailAddress":"camila.rojas@acme-pedidos.example","phoneNumber":"+51 1 555 0104","department":"Operaciones"}
{"userName":"martin.quispe","firstName":"Martín","lastName":"Quispe Huamán","title":"Supervisor de Almacén","gender":"Male","emailAddress":"martin.quispe@acme-pedidos.example","phoneNumber":"+51 1 555 0105","department":"Operaciones"}
{"userName":"diego.castillo","firstName":"Diego","lastName":"Castillo Núñez","title":"Coordinador de Logística","gender":"Male","emailAddress":"diego.castillo@acme-pedidos.example","phoneNumber":"+51 1 555 0106","department":"Logística"}
{"userName":"valeria.soto","firstName":"Valeria","lastName":"Soto Campos","title":"Analista de Finanzas y Cobranzas","gender":"Female","emailAddress":"valeria.soto@acme-pedidos.example","phoneNumber":"+51 1 555 0107","department":"Finanzas"}
{"userName":"sofia.herrera","firstName":"Sofía","lastName":"Herrera León","title":"Especialista de Servicio al Cliente","gender":"Female","emailAddress":"sofia.herrera@acme-pedidos.example","phoneNumber":"+51 1 555 0108","department":"Servicio al Cliente"}
{"userName":"bruno.navarro","firstName":"Bruno","lastName":"Navarro Gil","title":"Líder de Tecnología","gender":"Male","emailAddress":"bruno.navarro@acme-pedidos.example","phoneNumber":"+51 1 555 0109","department":"Tecnología"}
{"userName":"elena.paz","firstName":"Elena","lastName":"Paz Romero","title":"Coordinadora de Recursos Humanos","gender":"Female","emailAddress":"elena.paz@acme-pedidos.example","phoneNumber":"+51 1 555 0110","department":"Recursos Humanos"}
JSON

while IFS= read -r row; do
    name="$(jq -r '.name' <<<"$row")"
    payload="$(jq -c '.' <<<"$row")"
    ensure_record Account name "$name" "$payload" >/dev/null
done <<'JSON'
{"name":"Restaurante Sabor Peruano S.A.C.","type":"Customer","industry":"Food & Beverage","website":"https://sabor-peruano.example","emailAddress":"compras@sabor-peruano.example","phoneNumber":"+51 1 555 0201","billingAddressStreet":"Av. Arequipa 1830","billingAddressCity":"Lince","billingAddressState":"Lima","billingAddressCountry":"Perú","billingAddressPostalCode":"15046","shippingAddressStreet":"Jr. de la Unión 615","shippingAddressCity":"Lima","shippingAddressState":"Lima","shippingAddressCountry":"Perú","description":"Cliente corporativo. Cadena ficticia de 6 restaurantes. Condición comercial: crédito a 30 días. Frecuencia: pedidos semanales de insumos y empaques."}
{"name":"Hotel Miraflores Plaza","type":"Customer","industry":"Hospitality","website":"https://miraflores-plaza.example","emailAddress":"abastecimiento@miraflores-plaza.example","phoneNumber":"+51 1 555 0202","billingAddressStreet":"Av. José Larco 880","billingAddressCity":"Miraflores","billingAddressState":"Lima","billingAddressCountry":"Perú","billingAddressPostalCode":"15074","description":"Hotel ficticio de 120 habitaciones. Cuenta estratégica. Requiere entregas programadas y facturación consolidada mensual."}
{"name":"Cafetería Andina S.R.L.","type":"Customer","industry":"Food & Beverage","website":"https://cafeteria-andina.example","emailAddress":"administracion@cafeteria-andina.example","phoneNumber":"+51 1 555 0203","billingAddressStreet":"Av. Primavera 742","billingAddressCity":"Santiago de Surco","billingAddressState":"Lima","billingAddressCountry":"Perú","description":"Cadena ficticia de cafeterías con 4 locales. Compra recurrente de empaques biodegradables y suministros."}
{"name":"Mercado Verde Orgánico","type":"Customer","industry":"Grocery","website":"https://mercado-verde.example","emailAddress":"pedidos@mercado-verde.example","phoneNumber":"+51 1 555 0204","billingAddressStreet":"Calle Los Pinos 245","billingAddressCity":"Barranco","billingAddressState":"Lima","billingAddressCountry":"Perú","description":"Tienda ficticia especializada en productos orgánicos. Prefiere empaques sostenibles y entregas con baja huella de carbono."}
{"name":"Clínica Bienestar Integral","type":"Customer","industry":"Healthcare","website":"https://bienestar-integral.example","emailAddress":"logistica@bienestar-integral.example","phoneNumber":"+51 1 555 0205","billingAddressStreet":"Av. Guardia Civil 421","billingAddressCity":"San Borja","billingAddressState":"Lima","billingAddressCountry":"Perú","description":"Clínica ficticia. Cuenta regulada con requisitos de trazabilidad, lote, fecha de vencimiento y recepción documentada."}
{"name":"Universidad Horizonte","type":"Customer","industry":"Education","website":"https://universidad-horizonte.example","emailAddress":"compras@universidad-horizonte.example","phoneNumber":"+51 1 555 0206","billingAddressStreet":"Av. Universitaria 3500","billingAddressCity":"San Martín de Porres","billingAddressState":"Lima","billingAddressCountry":"Perú","description":"Institución educativa ficticia. Compras mediante órdenes y centros de costo. Campañas estacionales al inicio de cada ciclo."}
{"name":"Constructora Pacífico S.A.","type":"Customer","industry":"Construction","website":"https://constructora-pacifico.example","emailAddress":"procurement@constructora-pacifico.example","phoneNumber":"+51 1 555 0207","billingAddressStreet":"Av. República de Panamá 3055","billingAddressCity":"San Isidro","billingAddressState":"Lima","billingAddressCountry":"Perú","description":"Constructora ficticia con múltiples obras activas. Entregas por proyecto y control por guía de remisión."}
{"name":"Distribuidora Norte Chico","type":"Reseller","industry":"Wholesale","website":"https://norte-chico.example","emailAddress":"ventas@norte-chico.example","phoneNumber":"+51 1 555 0208","billingAddressStreet":"Panamericana Norte Km 36","billingAddressCity":"Ancón","billingAddressState":"Lima","billingAddressCountry":"Perú","description":"Distribuidor ficticio regional. Revende el portafolio ACME en Lima Norte y provincias cercanas."}
{"name":"Empaques Lima Eco","type":"Partner","industry":"Manufacturing","website":"https://empaques-lima.example","emailAddress":"comercial@empaques-lima.example","phoneNumber":"+51 1 555 0301","billingAddressStreet":"Av. Argentina 2880","billingAddressCity":"Callao","billingAddressState":"Callao","billingAddressCountry":"Perú","description":"Proveedor ficticio de cajas, bolsas y empaques biodegradables. Lead time: 5 días. Evaluación de proveedor: A."}
{"name":"Logística Rápida del Perú","type":"Partner","industry":"Transportation","website":"https://logistica-rapida.example","emailAddress":"operaciones@logistica-rapida.example","phoneNumber":"+51 1 555 0302","billingAddressStreet":"Av. Elmer Faucett 1950","billingAddressCity":"Callao","billingAddressState":"Callao","billingAddressCountry":"Perú","description":"Operador logístico ficticio para última milla. Cobertura Lima Metropolitana. SLA: 95% de entregas en ventana."}
{"name":"FríoTech Soluciones","type":"Partner","industry":"Technology","website":"https://friotech.example","emailAddress":"soporte@friotech.example","phoneNumber":"+51 1 555 0303","billingAddressStreet":"Av. Canadá 1470","billingAddressCity":"La Victoria","billingAddressState":"Lima","billingAddressCountry":"Perú","description":"Proveedor ficticio de sensores, cadena de frío y monitoreo IoT para pedidos sensibles."}
{"name":"Alimentos del Valle","type":"Partner","industry":"Food & Beverage","website":"https://alimentos-valle.example","emailAddress":"mayoristas@alimentos-valle.example","phoneNumber":"+51 1 555 0304","billingAddressStreet":"Carretera Central Km 15","billingAddressCity":"Chaclacayo","billingAddressState":"Lima","billingAddressCountry":"Perú","description":"Proveedor ficticio mayorista de alimentos no perecibles. Lead time: 72 horas. Entrega con control de lote."}
JSON

while IFS= read -r row; do
    email="$(jq -r '.emailAddress' <<<"$row")"
    account_name="$(jq -r '.accountName' <<<"$row")"
    account_id="$(find_id Account name "$account_name")"
    payload="$(jq -c --arg accountId "$account_id" 'del(.accountName) + {accountId: $accountId}' <<<"$row")"
    ensure_record Contact emailAddress "$email" "$payload" >/dev/null
done <<'JSON'
{"firstName":"Rosa","lastName":"Campos Valdivia","title":"Jefa de Compras","emailAddress":"rosa.campos@sabor-peruano.example","phoneNumber":"+51 1 555 1201","addressStreet":"Av. Arequipa 1830","addressCity":"Lince","addressState":"Lima","addressCountry":"Perú","accountName":"Restaurante Sabor Peruano S.A.C.","accountRole":"Decisora de compra","description":"Contacto principal. Prefiere comunicación por correo y reunión mensual de abastecimiento."}
{"firstName":"Jorge","lastName":"Salazar Peña","title":"Administrador de Operaciones","emailAddress":"jorge.salazar@sabor-peruano.example","phoneNumber":"+51 1 555 1202","addressCity":"Lince","addressState":"Lima","addressCountry":"Perú","accountName":"Restaurante Sabor Peruano S.A.C.","accountRole":"Usuario operativo"}
{"firstName":"Paola","lastName":"Benavides Ruiz","title":"Gerente de Abastecimiento","emailAddress":"paola.benavides@miraflores-plaza.example","phoneNumber":"+51 1 555 1203","addressCity":"Miraflores","addressState":"Lima","addressCountry":"Perú","accountName":"Hotel Miraflores Plaza","accountRole":"Decisora de compra","description":"Cuenta estratégica. Requiere reporte de OTIF mensual."}
{"firstName":"Renato","lastName":"Cárdenas Flores","title":"Supervisor de Almacén","emailAddress":"renato.cardenas@miraflores-plaza.example","phoneNumber":"+51 1 555 1204","addressCity":"Miraflores","addressState":"Lima","addressCountry":"Perú","accountName":"Hotel Miraflores Plaza","accountRole":"Recepción"}
{"firstName":"Lucía","lastName":"Vargas Ugarte","title":"Socia Administradora","emailAddress":"lucia.vargas@cafeteria-andina.example","phoneNumber":"+51 1 555 1205","addressCity":"Santiago de Surco","addressState":"Lima","addressCountry":"Perú","accountName":"Cafetería Andina S.R.L.","accountRole":"Decisora de compra"}
{"firstName":"Fernando","lastName":"Ponce Arias","title":"Encargado de Sostenibilidad","emailAddress":"fernando.ponce@mercado-verde.example","phoneNumber":"+51 1 555 1206","addressCity":"Barranco","addressState":"Lima","addressCountry":"Perú","accountName":"Mercado Verde Orgánico","accountRole":"Influenciador","description":"Prioriza certificados ambientales y reducción de plástico."}
{"firstName":"Mariana","lastName":"Delgado Cruz","title":"Coordinadora de Logística Clínica","emailAddress":"mariana.delgado@bienestar-integral.example","phoneNumber":"+51 1 555 1207","addressCity":"San Borja","addressState":"Lima","addressCountry":"Perú","accountName":"Clínica Bienestar Integral","accountRole":"Decisora de compra"}
{"firstName":"Óscar","lastName":"Gutiérrez Lama","title":"Analista de Compras","emailAddress":"oscar.gutierrez@universidad-horizonte.example","phoneNumber":"+51 1 555 1208","addressCity":"San Martín de Porres","addressState":"Lima","addressCountry":"Perú","accountName":"Universidad Horizonte","accountRole":"Comprador"}
{"firstName":"Natalia","lastName":"Reyes Chávez","title":"Jefa de Procurement","emailAddress":"natalia.reyes@constructora-pacifico.example","phoneNumber":"+51 1 555 1209","addressCity":"San Isidro","addressState":"Lima","addressCountry":"Perú","accountName":"Constructora Pacífico S.A.","accountRole":"Decisora de compra"}
{"firstName":"Héctor","lastName":"Luna Carrasco","title":"Gerente Regional","emailAddress":"hector.luna@norte-chico.example","phoneNumber":"+51 1 555 1210","addressCity":"Ancón","addressState":"Lima","addressCountry":"Perú","accountName":"Distribuidora Norte Chico","accountRole":"Socio comercial"}
{"firstName":"Patricia","lastName":"Yáñez Roldán","title":"Ejecutiva B2B","emailAddress":"patricia.yanez@empaques-lima.example","phoneNumber":"+51 1 555 1301","addressCity":"Callao","addressState":"Callao","addressCountry":"Perú","accountName":"Empaques Lima Eco","accountRole":"Proveedora"}
{"firstName":"Alonso","lastName":"Merino Tapia","title":"Coordinador de Flota","emailAddress":"alonso.merino@logistica-rapida.example","phoneNumber":"+51 1 555 1302","addressCity":"Callao","addressState":"Callao","addressCountry":"Perú","accountName":"Logística Rápida del Perú","accountRole":"Proveedor logístico"}
JSON

while IFS= read -r row; do
    email="$(jq -r '.emailAddress' <<<"$row")"
    owner="$(jq -r '.owner' <<<"$row")"
    owner_id="$(find_id User userName "$owner")"
    payload="$(jq -c --arg ownerId "$owner_id" 'del(.owner) + {assignedUserId: $ownerId}' <<<"$row")"
    ensure_record Lead emailAddress "$email" "$payload" >/dev/null
done <<'JSON'
{"firstName":"Gabriela","lastName":"Mora","title":"Gerente de Administración","accountName":"Panadería Central","status":"New","source":"Web Site","industry":"Food & Beverage","opportunityAmount":18500,"opportunityAmountCurrency":"USD","emailAddress":"gabriela.mora@panaderia-central.example","phoneNumber":"+51 1 555 1401","addressCity":"Jesús María","addressState":"Lima","addressCountry":"Perú","description":"Solicitó catálogo corporativo y propuesta para abastecimiento mensual.","owner":"mateo.silva"}
{"firstName":"Ricardo","lastName":"Palomino","title":"Jefe de Compras","accountName":"Grupo Gastronómico Sur","status":"In Process","source":"Call","industry":"Food & Beverage","opportunityAmount":32000,"opportunityAmountCurrency":"USD","emailAddress":"ricardo.palomino@gastronomico-sur.example","phoneNumber":"+51 1 555 1402","addressCity":"Chorrillos","addressState":"Lima","addressCountry":"Perú","description":"Evaluando consolidar proveedores para 12 locales.","owner":"luis.mendoza"}
{"firstName":"Carolina","lastName":"Espinoza","title":"Directora de Operaciones","accountName":"Colegio Nuevo Mundo","status":"Assigned","source":"Email","industry":"Education","opportunityAmount":12000,"opportunityAmountCurrency":"USD","emailAddress":"carolina.espinoza@colegio-nuevo-mundo.example","phoneNumber":"+51 1 555 1403","addressCity":"La Molina","addressState":"Lima","addressCountry":"Perú","description":"Interés en kits de bienvenida y suministros para el año académico.","owner":"mateo.silva"}
{"firstName":"Sebastián","lastName":"Valle","title":"Administrador","accountName":"Residencia Los Olivos","status":"New","source":"Partner","industry":"Healthcare","opportunityAmount":9800,"opportunityAmountCurrency":"USD","emailAddress":"sebastian.valle@residencia-olivos.example","phoneNumber":"+51 1 555 1404","addressCity":"Los Olivos","addressState":"Lima","addressCountry":"Perú","description":"Referido por Logística Rápida del Perú.","owner":"mateo.silva"}
{"firstName":"Daniela","lastName":"Fuentes","title":"Fundadora","accountName":"EcoBox Perú","status":"In Process","source":"Campaign","industry":"Retail","opportunityAmount":7500,"opportunityAmountCurrency":"USD","emailAddress":"daniela.fuentes@ecobox-peru.example","phoneNumber":"+51 1 555 1405","addressCity":"Barranco","addressState":"Lima","addressCountry":"Perú","description":"Respondió a campaña de empaques sostenibles.","owner":"luis.mendoza"}
{"firstName":"Miguel","lastName":"Arce","title":"Gerente de Proyectos","accountName":"Eventos 360","status":"New","source":"Existing Customer","industry":"Entertainment & Leisure","opportunityAmount":24000,"opportunityAmountCurrency":"USD","emailAddress":"miguel.arce@eventos360.example","phoneNumber":"+51 1 555 1406","addressCity":"Magdalena del Mar","addressState":"Lima","addressCountry":"Perú","description":"Requiere capacidad para pedidos urgentes durante campañas.","owner":"mateo.silva"}
JSON

while IFS= read -r row; do
    name="$(jq -r '.name' <<<"$row")"
    account_name="$(jq -r '.accountName' <<<"$row")"
    owner="$(jq -r '.owner' <<<"$row")"
    account_id="$(find_id Account name "$account_name")"
    owner_id="$(find_id User userName "$owner")"
    payload="$(jq -c \
        --arg accountId "$account_id" \
        --arg ownerId "$owner_id" \
        'del(.accountName, .owner) + {accountId: $accountId, assignedUserId: $ownerId, amountCurrency: "USD"}' <<<"$row")"
    ensure_record Opportunity name "$name" "$payload" >/dev/null
done <<'JSON'
{"name":"PED-2026-001 | Insumos semanales - Sabor Peruano","accountName":"Restaurante Sabor Peruano S.A.C.","stage":"Closed Won","probability":100,"amount":12800,"closeDate":"2026-08-05","leadSource":"Existing Customer","description":"Pedido completado: 480 cajas de insumos secos, 12 referencias. Entrega completa y conforme. OC ficticia: OC-SP-4471.","owner":"mateo.silva"}
{"name":"PED-2026-002 | Amenities corporativos - Hotel Miraflores","accountName":"Hotel Miraflores Plaza","stage":"Closed Won","probability":100,"amount":24600,"closeDate":"2026-08-12","leadSource":"Existing Customer","description":"Pedido completado: amenities y suministros para habitaciones. Entrega en dos ventanas. Facturación consolidada.","owner":"luis.mendoza"}
{"name":"PED-2026-003 | Empaques biodegradables - Cafetería Andina","accountName":"Cafetería Andina S.R.L.","stage":"Closed Won","probability":100,"amount":9400,"closeDate":"2026-08-19","leadSource":"Existing Customer","description":"Pedido mensual para 4 locales. Incluye vasos, tapas, mangas térmicas y bolsas compostables.","owner":"mateo.silva"}
{"name":"PED-2026-004 | Reposición orgánica - Mercado Verde","accountName":"Mercado Verde Orgánico","stage":"Closed Won","probability":100,"amount":6750,"closeDate":"2026-08-24","leadSource":"Existing Customer","description":"Reposición quincenal entregada. Transporte agrupado de baja emisión.","owner":"mateo.silva"}
{"name":"PED-2026-005 | Suministros clínicos no médicos","accountName":"Clínica Bienestar Integral","stage":"Negotiation","probability":80,"amount":38700,"closeDate":"2026-09-08","leadSource":"Existing Customer","description":"Cotización final enviada. Pendiente validación de trazabilidad y aprobación del comité de compras.","owner":"luis.mendoza"}
{"name":"PED-2026-006 | Kits de bienvenida ciclo 2026-II","accountName":"Universidad Horizonte","stage":"Proposal","probability":60,"amount":41200,"closeDate":"2026-09-15","leadSource":"Campaign","description":"2,000 kits para estudiantes. Propuesta incluye empaquetado personalizado y entregas por facultad.","owner":"mateo.silva"}
{"name":"PED-2026-007 | Abastecimiento obra Costa Azul","accountName":"Constructora Pacífico S.A.","stage":"Qualification","probability":40,"amount":29300,"closeDate":"2026-09-22","leadSource":"Call","description":"Validando centros de costo, ventanas de descarga y documentación por obra.","owner":"luis.mendoza"}
{"name":"PED-2026-008 | Stock mayorista Lima Norte","accountName":"Distribuidora Norte Chico","stage":"Negotiation","probability":75,"amount":52800,"closeDate":"2026-09-10","leadSource":"Partner","description":"Pedido mayorista mixto. Negociación de descuento por volumen y exclusividad territorial trimestral.","owner":"luis.mendoza"}
{"name":"PED-2026-009 | Insumos septiembre - Sabor Peruano","accountName":"Restaurante Sabor Peruano S.A.C.","stage":"Proposal","probability":70,"amount":13650,"closeDate":"2026-09-05","leadSource":"Existing Customer","description":"Pedido recurrente. Se propone sustituir 20% de empaques por línea compostable.","owner":"mateo.silva"}
{"name":"PED-2026-010 | Reposición minibar Q3","accountName":"Hotel Miraflores Plaza","stage":"Prospecting","probability":20,"amount":17800,"closeDate":"2026-09-30","leadSource":"Existing Customer","description":"Estimación inicial para reposición del tercer trimestre.","owner":"mateo.silva"}
{"name":"PED-2026-011 | Empaques campaña primavera","accountName":"Cafetería Andina S.R.L.","stage":"Closed Lost","probability":0,"amount":11800,"closeDate":"2026-08-28","leadSource":"Existing Customer","description":"Perdido por fecha de entrega incompatible. Registrar aprendizaje para planificación estacional.","owner":"mateo.silva"}
{"name":"PED-2026-012 | Sensores de cadena de frío","accountName":"Clínica Bienestar Integral","stage":"Qualification","probability":35,"amount":22100,"closeDate":"2026-10-05","leadSource":"Partner","description":"Solución conjunta con FríoTech. Prueba piloto propuesta para dos puntos de almacenamiento.","owner":"luis.mendoza"}
JSON

while IFS= read -r row; do
    name="$(jq -r '.name' <<<"$row")"
    account_name="$(jq -r '.accountName' <<<"$row")"
    owner="$(jq -r '.owner' <<<"$row")"
    account_id="$(find_id Account name "$account_name")"
    owner_id="$(find_id User userName "$owner")"
    payload="$(jq -c --arg accountId "$account_id" --arg ownerId "$owner_id" 'del(.accountName, .owner) + {accountId: $accountId, assignedUserId: $ownerId}' <<<"$row")"
    ensure_record Case name "$name" "$payload" >/dev/null
done <<'JSON'
{"name":"ACME-CASO-001 | Diferencia de 4 unidades en recepción","accountName":"Restaurante Sabor Peruano S.A.C.","status":"Closed","priority":"Normal","type":"Incident","description":"Se detectó diferencia de 4 unidades en PED-2026-001. Se emitió nota y reposición en 24 horas. Causa: conteo manual.","owner":"sofia.herrera"}
{"name":"ACME-CASO-002 | Consulta sobre certificado compostable","accountName":"Mercado Verde Orgánico","status":"Closed","priority":"Low","type":"Question","description":"Se remitieron certificados técnicos y declaración del proveedor Empaques Lima Eco.","owner":"sofia.herrera"}
{"name":"ACME-CASO-003 | Ventana de entrega restringida","accountName":"Hotel Miraflores Plaza","status":"Pending","priority":"High","type":"Problem","description":"Cliente solicita entregas únicamente entre 06:00 y 08:00. Pendiente confirmar disponibilidad del operador logístico.","owner":"diego.castillo"}
{"name":"ACME-CASO-004 | Validación de lote y vencimiento","accountName":"Clínica Bienestar Integral","status":"Assigned","priority":"Urgent","type":"Question","description":"Se requiere matriz de trazabilidad antes de aprobar PED-2026-005.","owner":"camila.rojas"}
{"name":"ACME-CASO-005 | Factura consolidada agosto","accountName":"Cafetería Andina S.R.L.","status":"New","priority":"Normal","type":"Question","description":"Cliente solicita consolidar cuatro guías en una factura con detalle por local.","owner":"valeria.soto"}
{"name":"ACME-CASO-006 | Solicitud de cambio de dirección","accountName":"Distribuidora Norte Chico","status":"Assigned","priority":"High","type":"Incident","description":"Actualizar entrega de PED-2026-008 al almacén alterno de Puente Piedra antes del despacho.","owner":"diego.castillo"}
JSON

while IFS= read -r row; do
    name="$(jq -r '.name' <<<"$row")"
    parent_name="$(jq -r '.parentName // empty' <<<"$row")"
    owner="$(jq -r '.owner' <<<"$row")"
    owner_id="$(find_id User userName "$owner")"
    if [[ -n "$parent_name" ]]; then
        parent_id="$(find_id Opportunity name "$parent_name")"
        payload="$(jq -c --arg ownerId "$owner_id" --arg parentId "$parent_id" 'del(.owner, .parentName) + {assignedUserId: $ownerId, parentType: "Opportunity", parentId: $parentId}' <<<"$row")"
    else
        payload="$(jq -c --arg ownerId "$owner_id" 'del(.owner, .parentName) + {assignedUserId: $ownerId}' <<<"$row")"
    fi
    ensure_record Task name "$name" "$payload" >/dev/null
done <<'JSON'
{"name":"ACME-TAR-001 | Confirmar trazabilidad clínica","status":"Started","priority":"Urgent","dateStart":"2026-09-02 09:00:00","dateEnd":"2026-09-03 12:00:00","description":"Completar matriz de lote, vencimiento, proveedor y punto de recepción.","parentName":"PED-2026-005 | Suministros clínicos no médicos","owner":"camila.rojas"}
{"name":"ACME-TAR-002 | Validar descuento mayorista","status":"Started","priority":"High","dateStart":"2026-09-02 10:00:00","dateEnd":"2026-09-04 17:00:00","description":"Evaluar margen con descuento escalonado de 8%, 10% y 12%.","parentName":"PED-2026-008 | Stock mayorista Lima Norte","owner":"valeria.soto"}
{"name":"ACME-TAR-003 | Reservar capacidad de almacén","status":"Not Started","priority":"High","dateStart":"2026-09-04 08:00:00","dateEnd":"2026-09-08 18:00:00","description":"Separar posiciones para los 2,000 kits universitarios.","parentName":"PED-2026-006 | Kits de bienvenida ciclo 2026-II","owner":"martin.quispe"}
{"name":"ACME-TAR-004 | Confirmar dirección alterna","status":"Not Started","priority":"Urgent","dateStart":"2026-09-02 14:00:00","dateEnd":"2026-09-02 17:00:00","description":"Solicitar correo formal del cliente y actualizar instrucción de despacho.","parentName":"PED-2026-008 | Stock mayorista Lima Norte","owner":"diego.castillo"}
{"name":"ACME-TAR-005 | Preparar forecast octubre","status":"Not Started","priority":"Normal","dateStart":"2026-09-07 09:00:00","dateEnd":"2026-09-11 18:00:00","description":"Consolidar demanda ponderada del pipeline y pedidos recurrentes.","owner":"camila.rojas"}
{"name":"ACME-TAR-006 | Seguimiento lead Panadería Central","status":"Not Started","priority":"Normal","dateStart":"2026-09-03 10:00:00","dateEnd":"2026-09-03 11:00:00","description":"Confirmar volúmenes, frecuencia y fecha de decisión.","owner":"mateo.silva"}
{"name":"ACME-TAR-007 | Revisar cobranza Hotel Miraflores","status":"Started","priority":"High","dateStart":"2026-09-01 09:00:00","dateEnd":"2026-09-05 17:00:00","description":"Conciliar factura de agosto y fecha programada de pago.","owner":"valeria.soto"}
{"name":"ACME-TAR-008 | Capacitación uso del CRM","status":"Completed","priority":"Normal","dateStart":"2026-08-28 15:00:00","dateEnd":"2026-08-28 17:00:00","description":"Sesión interna sobre cuentas, contactos, pipeline, casos y actividades.","owner":"bruno.navarro"}
JSON

while IFS= read -r row; do
    name="$(jq -r '.name' <<<"$row")"
    parent_name="$(jq -r '.parentName' <<<"$row")"
    owner="$(jq -r '.owner' <<<"$row")"
    account_id="$(find_id Account name "$parent_name")"
    owner_id="$(find_id User userName "$owner")"
    payload="$(jq -c --arg ownerId "$owner_id" --arg parentId "$account_id" 'del(.owner, .parentName) + {assignedUserId: $ownerId, usersIds: [$ownerId], parentType: "Account", parentId: $parentId}' <<<"$row")"
    ensure_record Meeting name "$name" "$payload" >/dev/null
done <<'JSON'
{"name":"ACME-REU-001 | Comité semanal de pedidos","status":"Planned","dateStart":"2026-09-04 15:00:00","dateEnd":"2026-09-04 16:00:00","duration":3600,"description":"Revisar backlog, capacidad, riesgos de entrega y cobranzas críticas.","parentName":"ACME Pedidos S.A.C.","owner":"camila.rojas"}
{"name":"ACME-REU-002 | Negociación Distribuidora Norte Chico","status":"Planned","dateStart":"2026-09-03 16:00:00","dateEnd":"2026-09-03 17:00:00","duration":3600,"description":"Cerrar volumen, descuento y condición de exclusividad.","parentName":"Distribuidora Norte Chico","owner":"luis.mendoza"}
{"name":"ACME-REU-003 | Revisión SLA Hotel Miraflores","status":"Planned","dateStart":"2026-09-08 09:00:00","dateEnd":"2026-09-08 10:00:00","duration":3600,"description":"Revisar OTIF, ventanas de entrega e incidencias del trimestre.","parentName":"Hotel Miraflores Plaza","owner":"diego.castillo"}
{"name":"ACME-REU-004 | Kickoff kits Universidad Horizonte","status":"Planned","dateStart":"2026-09-10 11:00:00","dateEnd":"2026-09-10 12:00:00","duration":3600,"description":"Alinear diseño, cantidades, empaquetado y entregas por facultad.","parentName":"Universidad Horizonte","owner":"mateo.silva"}
JSON

while IFS= read -r row; do
    name="$(jq -r '.name' <<<"$row")"
    parent_name="$(jq -r '.parentName' <<<"$row")"
    owner="$(jq -r '.owner' <<<"$row")"
    account_id="$(find_id Account name "$parent_name")"
    owner_id="$(find_id User userName "$owner")"
    payload="$(jq -c --arg ownerId "$owner_id" --arg parentId "$account_id" 'del(.owner, .parentName) + {assignedUserId: $ownerId, usersIds: [$ownerId], parentType: "Account", parentId: $parentId}' <<<"$row")"
    ensure_record Call name "$name" "$payload" >/dev/null
done <<'JSON'
{"name":"ACME-LLA-001 | Seguimiento propuesta clínica","status":"Planned","direction":"Outbound","dateStart":"2026-09-03 09:30:00","dateEnd":"2026-09-03 10:00:00","duration":1800,"description":"Confirmar observaciones del comité y fecha estimada de orden de compra.","parentName":"Clínica Bienestar Integral","owner":"luis.mendoza"}
{"name":"ACME-LLA-002 | Coordinación dirección alterna","status":"Planned","direction":"Outbound","dateStart":"2026-09-02 16:00:00","dateEnd":"2026-09-02 16:30:00","duration":1800,"description":"Validar acceso, responsable de recepción y ventana de descarga.","parentName":"Distribuidora Norte Chico","owner":"diego.castillo"}
{"name":"ACME-LLA-003 | Postventa pedido agosto","status":"Held","direction":"Outbound","dateStart":"2026-08-26 11:00:00","dateEnd":"2026-08-26 11:15:00","duration":900,"description":"Cliente confirmó entrega conforme y solicitó propuesta de septiembre.","parentName":"Restaurante Sabor Peruano S.A.C.","owner":"sofia.herrera"}
{"name":"ACME-LLA-004 | Consulta factura consolidada","status":"Held","direction":"Inbound","dateStart":"2026-09-01 14:00:00","dateEnd":"2026-09-01 14:15:00","duration":900,"description":"Se explicó proceso; pendiente envío de desglose por local.","parentName":"Cafetería Andina S.R.L.","owner":"valeria.soto"}
JSON

echo
echo "ACME demo data is ready."
for entity in Account Contact Lead Opportunity Case Task Meeting Call Team User; do
    total="$(api_get "$BASE_URL/$entity?maxSize=1" | jq -r '.total')"
    printf '%-12s %s total records\n' "$entity" "$total"
done
