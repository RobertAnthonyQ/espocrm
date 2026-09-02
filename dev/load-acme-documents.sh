#!/usr/bin/env bash

set -euo pipefail

BASE_URL="${ESPO_BASE_URL:-http://localhost:8080/api/v1}"
ADMIN_USER="${ESPO_ADMIN_USER:-admin}"
ADMIN_PASSWORD="${ESPO_ADMIN_PASSWORD:?Set ESPO_ADMIN_PASSWORD}"
PDF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../output/pdf" && pwd)"

request() {
    local method="$1"
    local url="$2"
    local body="${3:-}"

    if [[ -n "$body" ]]; then
        curl --fail-with-body --silent --show-error -u "$ADMIN_USER:$ADMIN_PASSWORD" \
            -H 'Content-Type: application/json' -X "$method" --data "$body" "$BASE_URL/$url"
    else
        curl --fail-with-body --silent --show-error -u "$ADMIN_USER:$ADMIN_PASSWORD" \
            -X "$method" "$BASE_URL/$url"
    fi
}

find_id() {
    local entity="$1"
    local attribute="$2"
    local value="$3"

    curl --fail-with-body --silent --show-error -u "$ADMIN_USER:$ADMIN_PASSWORD" --get \
        --data-urlencode "where[0][type]=equals" \
        --data-urlencode "where[0][attribute]=$attribute" \
        --data-urlencode "where[0][value]=$value" \
        "$BASE_URL/$entity" | jq -r '.list[0].id // empty'
}

upload_pdf() {
    local entity="$1"
    local field="$2"
    local filename="$3"
    local encoded payload

    encoded="$(base64 < "$PDF_DIR/$filename" | tr -d '\n')"
    payload="$(jq -nc --arg name "$filename" --arg relatedType "$entity" --arg field "$field" \
        --arg file "data:application/pdf;base64,$encoded" \
        '{name:$name,type:"application/pdf",role:"Attachment",relatedType:$relatedType,field:$field,file:$file}')"
    request POST Attachment "$payload" | jq -r '.id'
}

echo "Loading client TDRs..."
while IFS= read -r row; do
    client="$(jq -r '.client' <<<"$row")"
    filename="$(jq -r '.file' <<<"$row")"
    account_id="$(find_id Account name "$client")"

    if [[ -z "$account_id" ]]; then
        echo "Missing account: $client" >&2
        exit 1
    fi

    current="$(request GET "Account/$account_id")"
    attachment_id="$(jq -r '.cTdrFileId // empty' <<<"$current")"
    if [[ -z "$attachment_id" ]]; then
        attachment_id="$(upload_pdf Account cTdrFile "$filename")"
    fi

    payload="$(jq -c --arg attachmentId "$attachment_id" \
        'del(.client,.file) + {cTdrFileId:$attachmentId,cContractValueCurrency:"PEN"}' <<<"$row")"
    request PUT "Account/$account_id" "$payload" >/dev/null
    printf 'ready   TDR       %s\n' "$client"
done <<'JSON'
{"client":"Restaurante Sabor Peruano S.A.C.","file":"tdr-001-restaurante-sabor-peruano.pdf","cTdrStatus":"Vigente","cServiceType":"Abastecimiento recurrente","cTdrStartDate":"2026-01-01","cTdrEndDate":"2026-12-31","cContractValue":78000,"cServiceLevel":"Entrega completa en máximo 24 horas","cTdrSummary":"Insumos secos, bebidas y empaques para tres locales. Dos entregas semanales, atención de urgencias y reporte mensual de consumo."}
{"client":"Hotel Miraflores Plaza","file":"tdr-002-hotel-miraflores-plaza.pdf","cTdrStatus":"Vigente","cServiceType":"Kits corporativos","cTdrStartDate":"2026-01-15","cTdrEndDate":"2027-01-14","cContractValue":96500,"cServiceLevel":"Confirmación en 2 horas y entrega en 48 horas","cTdrSummary":"Kits de bienvenida, amenities y materiales para eventos con personalización, control de lote e inventario semanal."}
{"client":"Cafetería Andina S.R.L.","file":"tdr-003-cafeteria-andina.pdf","cTdrStatus":"Vigente","cServiceType":"Gestión de pedidos","cTdrStartDate":"2026-02-01","cTdrEndDate":"2027-01-31","cContractValue":54000,"cServiceLevel":"Despacho antes de las 07:00 del día siguiente","cTdrSummary":"Pedidos diarios de suministros y descartables para cinco puntos de venta, con consolidado semanal y alertas de stock."}
{"client":"Mercado Verde Orgánico","file":"tdr-004-mercado-verde-organico.pdf","cTdrStatus":"Vigente","cServiceType":"Logística y distribución","cTdrStartDate":"2026-03-01","cTdrEndDate":"2027-02-28","cContractValue":118000,"cServiceLevel":"95% de entregas en ventana de 2 horas","cTdrSummary":"Recojo y distribución de canastas con planificación de rutas, trazabilidad, evidencia de entrega y control de merma."}
{"client":"Clínica Bienestar Integral","file":"tdr-005-clinica-bienestar-integral.pdf","cTdrStatus":"Vigente","cServiceType":"Cadena de frío","cTdrStartDate":"2026-04-01","cTdrEndDate":"2027-03-31","cContractValue":156000,"cServiceLevel":"Temperatura controlada y respuesta crítica en 60 minutos","cTdrSummary":"Transporte de insumos sensibles entre 2 °C y 8 °C, registro continuo, sensores calibrados y protocolo de contingencia."}
{"client":"Universidad Horizonte","file":"tdr-006-universidad-horizonte.pdf","cTdrStatus":"Vigente","cServiceType":"Servicio integral","cTdrStartDate":"2026-03-15","cTdrEndDate":"2027-03-14","cContractValue":132000,"cServiceLevel":"Atención de requerimientos ordinarios en 72 horas","cTdrSummary":"Materiales académicos, administrativos y para eventos en dos campus, clasificados por centro de costo."}
{"client":"Constructora Pacífico S.A.","file":"tdr-007-constructora-pacifico.pdf","cTdrStatus":"Vigente","cServiceType":"Abastecimiento recurrente","cTdrStartDate":"2026-05-01","cTdrEndDate":"2027-04-30","cContractValue":210000,"cServiceLevel":"Puntualidad mínima de 96% en entregas programadas","cTdrSummary":"Equipos de protección, consumibles y suministros homologados para tres obras, con control por frente de trabajo."}
{"client":"Distribuidora Norte Chico","file":"tdr-008-distribuidora-norte-chico.pdf","cTdrStatus":"Vigente","cServiceType":"Logística y distribución","cTdrStartDate":"2026-06-01","cTdrEndDate":"2027-05-31","cContractValue":144000,"cServiceLevel":"Salida en 24 horas y trazabilidad hasta destino","cTdrSummary":"Consolidación y despacho hacia Huacho, Huaral y Barranca, con manifiesto de carga, evidencias y devoluciones."}
JSON

finance_user_id="$(find_id User userName valeria.soto)"

echo "Loading expense invoices..."
while IFS= read -r row; do
    number="$(jq -r '.documentNumber' <<<"$row")"
    existing_id="$(find_id CGasto documentNumber "$number")"
    if [[ -n "$existing_id" ]]; then
        printf 'reused  expense   %s\n' "$number"
        continue
    fi

    supplier="$(jq -r '.supplier' <<<"$row")"
    order="$(jq -r '.order' <<<"$row")"
    filename="$(jq -r '.file' <<<"$row")"
    supplier_id="$(find_id Account name "$supplier")"
    order_id="$(find_id Opportunity name "$order")"

    if [[ -z "$supplier_id" || -z "$order_id" ]]; then
        echo "Missing relation for expense $number" >&2
        exit 1
    fi

    attachment_id="$(upload_pdf CGasto invoiceFile "$filename")"
    payload="$(jq -c --arg supplierId "$supplier_id" --arg orderId "$order_id" \
        --arg attachmentId "$attachment_id" --arg ownerId "$finance_user_id" \
        'del(.supplier,.order,.file) + {
          proveedorId:$supplierId,pedidoId:$orderId,invoiceFileId:$attachmentId,assignedUserId:$ownerId,
          subtotalCurrency:"PEN",taxAmountCurrency:"PEN",totalAmountCurrency:"PEN"
        }' <<<"$row")"
    request POST CGasto "$payload" >/dev/null
    printf 'created expense   %s\n' "$number"
done <<'JSON'
{"name":"F001-0831 | Empaques sostenibles","documentType":"Factura","documentNumber":"F001-0831","issueDate":"2026-08-12","dueDate":"2026-09-11","category":"Operaciones","costCenter":"Operaciones","subtotal":4720,"taxAmount":849.60,"totalAmount":5569.60,"paymentStatus":"Pagado","paymentMethod":"Transferencia bancaria","paymentDate":"2026-08-20","deductible":true,"supplier":"Empaques Lima Eco","order":"PED-2026-003 | Empaques biodegradables - Cafetería Andina","file":"gasto-001-empaques-lima-eco.pdf","description":"Compra de cajas kraft, bolsas compostables y etiquetas para pedidos recurrentes."}
{"name":"F001-1842 | Reparto urbano julio","documentType":"Factura","documentNumber":"F001-1842","issueDate":"2026-08-15","dueDate":"2026-09-14","category":"Logística y transporte","costCenter":"Logística","subtotal":3200,"taxAmount":576,"totalAmount":3776,"paymentStatus":"Pagado","paymentMethod":"Transferencia bancaria","paymentDate":"2026-08-29","deductible":true,"supplier":"Logística Rápida del Perú","order":"PED-2026-001 | Insumos semanales - Sabor Peruano","file":"gasto-002-logistica-rapida.pdf","description":"Servicio consolidado de reparto urbano correspondiente a julio de 2026."}
{"name":"FT01-0098 | Mantenimiento cadena de frío","documentType":"Factura","documentNumber":"FT01-0098","issueDate":"2026-08-18","dueDate":"2026-09-17","category":"Tecnología","costCenter":"Tecnología","subtotal":8500,"taxAmount":1530,"totalAmount":10030,"paymentStatus":"Pendiente de pago","paymentMethod":"Transferencia bancaria","deductible":true,"supplier":"FríoTech Soluciones","order":"PED-2026-012 | Sensores de cadena de frío","file":"gasto-003-friotech.pdf","description":"Mantenimiento preventivo de unidad refrigerada y calibración de sensores."}
{"name":"F002-0441 | Insumos secos agosto","documentType":"Factura","documentNumber":"F002-0441","issueDate":"2026-08-20","dueDate":"2026-09-19","category":"Operaciones","costCenter":"Operaciones","subtotal":12600,"taxAmount":2268,"totalAmount":14868,"paymentStatus":"Pagado","paymentMethod":"Transferencia bancaria","paymentDate":"2026-09-01","deductible":true,"supplier":"Alimentos del Valle","order":"PED-2026-001 | Insumos semanales - Sabor Peruano","file":"gasto-004-alimentos-del-valle.pdf","description":"Compra mayorista de insumos alimentarios secos, lote agosto de 2026."}
{"name":"F001-1865 | Ruta Norte Chico","documentType":"Factura","documentNumber":"F001-1865","issueDate":"2026-08-25","dueDate":"2026-09-24","category":"Logística y transporte","costCenter":"Logística","subtotal":5980,"taxAmount":1076.40,"totalAmount":7056.40,"paymentStatus":"Registrado","paymentMethod":"Transferencia bancaria","deductible":true,"supplier":"Logística Rápida del Perú","order":"PED-2026-008 | Stock mayorista Lima Norte","file":"gasto-005-logistica-ruta-norte.pdf","description":"Distribución interprovincial de carga consolidada hacia la ruta Norte Chico."}
{"name":"F001-0856 | Empaques para kits","documentType":"Factura","documentNumber":"F001-0856","issueDate":"2026-08-28","dueDate":"2026-09-27","category":"Operaciones","costCenter":"Operaciones","subtotal":7350,"taxAmount":1323,"totalAmount":8673,"paymentStatus":"Pendiente de pago","paymentMethod":"Transferencia bancaria","deductible":true,"supplier":"Empaques Lima Eco","order":"PED-2026-002 | Amenities corporativos - Hotel Miraflores","file":"gasto-006-empaques-kits.pdf","description":"Empaques personalizados para kits corporativos y amenities."}
JSON

echo "ACME documents loaded."
