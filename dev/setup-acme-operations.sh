#!/usr/bin/env bash

set -euo pipefail

BASE_URL="${ESPO_BASE_URL:-http://localhost:8080/api/v1}"
ADMIN_USER="${ESPO_ADMIN_USER:-admin}"
ADMIN_PASSWORD="${ESPO_ADMIN_PASSWORD:?Set ESPO_ADMIN_PASSWORD}"

request() {
    local method="$1"
    local url="$2"
    local body="${3:-}"

    if [[ -n "$body" ]]; then
        curl --fail-with-body --silent --show-error \
            -u "$ADMIN_USER:$ADMIN_PASSWORD" \
            -H 'Content-Type: application/json' \
            -X "$method" --data "$body" "$BASE_URL/$url"
    else
        curl --fail-with-body --silent --show-error \
            -u "$ADMIN_USER:$ADMIN_PASSWORD" \
            -X "$method" "$BASE_URL/$url"
    fi
}

metadata() {
    request GET Metadata
}

ensure_entity() {
    local requested_name="$1"
    local actual_name="$2"
    local singular="$3"
    local plural="$4"
    local icon="$5"

    if metadata | jq -e --arg name "$actual_name" '.scopes[$name] != null' >/dev/null; then
        echo "reused  entity $actual_name"
        return
    fi

    request POST EntityManager/action/createEntity "$(jq -nc \
        --arg name "$requested_name" --arg singular "$singular" --arg plural "$plural" --arg icon "$icon" \
        '{name: $name, labelSingular: $singular, labelPlural: $plural, type: "BasePlus", stream: true, iconClass: $icon}')" >/dev/null
    request POST Admin/rebuild '{}' >/dev/null
    echo "created entity $actual_name"
}

ensure_field() {
    local scope="$1"
    local requested_name="$2"
    local actual_name="$3"
    local label="$4"
    local type="$5"
    local params="${6:-}"
    local code

    if [[ -z "$params" ]]; then
        params='{}'
    fi

    code="$(curl --silent --output /dev/null --write-out '%{http_code}' \
        -u "$ADMIN_USER:$ADMIN_PASSWORD" "$BASE_URL/Admin/fieldManager/$scope/$actual_name")"

    if [[ "$code" == "200" ]]; then
        echo "reused  field $scope.$actual_name"
        return
    fi

    request POST "Admin/fieldManager/$scope" "$(jq -nc \
        --arg name "$requested_name" --arg label "$label" --arg type "$type" --argjson params "$params" \
        '{name: $name, label: $label, type: $type} + $params')" >/dev/null
    echo "created field $scope.$actual_name"
}

ensure_link() {
    local entity="$1"
    local entity_foreign="$2"
    local link="$3"
    local link_foreign="$4"
    local label="$5"
    local label_foreign="$6"

    if metadata | jq -e --arg entity "$entity" --arg link "$link" '.entityDefs[$entity].links[$link] != null' >/dev/null; then
        echo "reused  link $entity.$link"
        return
    fi

    request POST EntityManager/action/createLink "$(jq -nc \
        --arg entity "$entity" --arg foreign "$entity_foreign" \
        --arg link "$link" --arg linkForeign "$link_foreign" \
        --arg label "$label" --arg labelForeign "$label_foreign" \
        '{entity: $entity, entityForeign: $foreign, link: $link, linkForeign: $linkForeign,
          label: $label, labelForeign: $labelForeign, linkType: "manyToOne"}')" >/dev/null
    echo "created link $entity.$link -> $entity_foreign"
}

echo "Checking EspoCRM..."
request GET App/user >/dev/null

ensure_entity Gasto CGasto Gasto Gastos 'fas fa-file-invoice-dollar'

ensure_field CGasto documentType documentType 'Tipo de comprobante' enum \
    '{"required":true,"options":["Factura","Boleta","Recibo por honorarios","Nota de crédito","Otro"],"default":"Factura","displayAsLabel":true,"audited":true}'
ensure_field CGasto documentNumber documentNumber 'Número de comprobante' varchar \
    '{"required":true,"maxLength":50,"copyToClipboard":true,"audited":true}'
ensure_field CGasto issueDate issueDate 'Fecha de emisión' date \
    '{"required":true,"audited":true}'
ensure_field CGasto dueDate dueDate 'Fecha de vencimiento' date \
    '{"audited":true}'
ensure_field CGasto category category Categoría enum \
    '{"required":true,"options":["Operaciones","Logística y transporte","Tecnología","Marketing","Servicios profesionales","Alquiler y servicios","Recursos humanos","Tributos","Otros"],"displayAsLabel":true,"audited":true}'
ensure_field CGasto costCenter costCenter 'Centro de costo' enum \
    '{"required":true,"options":["Dirección General","Ventas","Operaciones","Logística","Finanzas","Servicio al Cliente","Tecnología","Recursos Humanos"],"displayAsLabel":true,"audited":true}'
ensure_field CGasto subtotal subtotal Subtotal currency \
    '{"required":true,"min":0,"audited":true}'
ensure_field CGasto taxAmount taxAmount IGV currency \
    '{"required":true,"min":0,"audited":true}'
ensure_field CGasto totalAmount totalAmount Total currency \
    '{"required":true,"min":0,"audited":true}'
ensure_field CGasto paymentStatus paymentStatus 'Estado de pago' enum \
    '{"required":true,"options":["Registrado","Pendiente de pago","Pagado","Anulado"],"default":"Registrado","displayAsLabel":true,"audited":true,"style":{"Registrado":"info","Pendiente de pago":"warning","Pagado":"success","Anulado":"danger"}}'
ensure_field CGasto paymentMethod paymentMethod 'Método de pago' enum \
    '{"options":["Transferencia bancaria","Tarjeta corporativa","Caja chica","Débito automático","Otro"],"displayAsLabel":true,"audited":true}'
ensure_field CGasto paymentDate paymentDate 'Fecha de pago' date \
    '{"audited":true}'
ensure_field CGasto invoiceFile invoiceFile 'Factura / sustento PDF' file \
    '{"required":false,"accept":[".pdf"],"maxFileSize":20,"audited":true}'
ensure_field CGasto xmlFile xmlFile 'Archivo XML' file \
    '{"accept":[".xml","text/xml","application/xml"],"maxFileSize":10,"audited":true}'
ensure_field CGasto deductible deductible 'Gasto deducible' bool \
    '{"default":true,"audited":true}'

ensure_link CGasto Account proveedor cGastos Proveedor Gastos
ensure_link CGasto Opportunity pedido cGastos 'Pedido relacionado' Gastos

ensure_field Account tdrFile cTdrFile 'TDR / Requerimiento PDF' file \
    '{"accept":[".pdf"],"maxFileSize":30,"audited":true}'
ensure_field Account tdrStatus cTdrStatus 'Estado contractual' enum \
    '{"options":["Sin TDR","En evaluación","Vigente","Por renovar","Vencido"],"default":"Sin TDR","displayAsLabel":true,"audited":true,"style":{"Sin TDR":"default","En evaluación":"info","Vigente":"success","Por renovar":"warning","Vencido":"danger"}}'
ensure_field Account serviceType cServiceType 'Servicio contratado' enum \
    '{"options":["Abastecimiento recurrente","Gestión de pedidos","Logística y distribución","Kits corporativos","Cadena de frío","Servicio integral"],"displayAsLabel":true,"audited":true}'
ensure_field Account tdrStartDate cTdrStartDate 'Inicio del servicio' date \
    '{"audited":true}'
ensure_field Account tdrEndDate cTdrEndDate 'Fin del servicio' date \
    '{"audited":true}'
ensure_field Account contractValue cContractValue 'Valor contractual' currency \
    '{"min":0,"audited":true}'
ensure_field Account serviceLevel cServiceLevel 'SLA comprometido' varchar \
    '{"maxLength":150,"audited":true}'
ensure_field Account tdrSummary cTdrSummary 'Resumen de requerimientos' text \
    '{"rows":5,"cutHeight":300,"audited":true}'

account_detail="$(request GET 'Layout/action/getOriginal?scope=Account&name=detail')"
if ! jq -e 'map(.label) | index("TDR y condiciones del servicio") != null' <<<"$account_detail" >/dev/null; then
    account_detail="$(jq -c '. + [{
      label: "TDR y condiciones del servicio",
      rows: [
        [{name:"cTdrStatus"},{name:"cServiceType"}],
        [{name:"cTdrStartDate"},{name:"cTdrEndDate"}],
        [{name:"cContractValue"},{name:"cServiceLevel"}],
        [{name:"cTdrSummary",fullWidth:true}],
        [{name:"cTdrFile",fullWidth:true}]
      ]
    }]' <<<"$account_detail")"
    request PUT Account/layout/detail "$account_detail" >/dev/null
    echo "updated Account detail layout"
fi

account_panels="$(request GET 'Layout/action/getOriginal?scope=Account&name=bottomPanelsDetail')"
if ! jq -e '.cCGastos != null' <<<"$account_panels" >/dev/null; then
    account_panels="$(jq -c 'del(.cGastos) | .cCGastos = {index: 6} | to_entries | map(.value.index = (if .key == "cCGastos" then 6 else (if .value.index >= 6 then .value.index + 1 else .value.index end) end)) | from_entries' <<<"$account_panels")"
    request PUT Account/layout/bottomPanelsDetail "$account_panels" >/dev/null
    echo "updated Account related panels"
fi

opportunity_panels="$(request GET 'Layout/action/getOriginal?scope=Opportunity&name=bottomPanelsDetail')"
if ! jq -e '.cCGastos != null' <<<"$opportunity_panels" >/dev/null; then
    max_index="$(jq '[to_entries[].value.index // 0] | max // 0' <<<"$opportunity_panels")"
    opportunity_panels="$(jq -c --argjson index "$((max_index + 1))" 'del(.cGastos) | .cCGastos = {index: $index}' <<<"$opportunity_panels")"
    request PUT Opportunity/layout/bottomPanelsDetail "$opportunity_panels" >/dev/null
    echo "updated Opportunity related panels"
fi

gasto_detail='[
  {"label":"Comprobante","rows":[
    [{"name":"name"},{"name":"documentNumber"}],
    [{"name":"documentType"},{"name":"category"}],
    [{"name":"proveedor"},{"name":"pedido"}],
    [{"name":"issueDate"},{"name":"dueDate"}]
  ]},
  {"label":"Importes y pago","rows":[
    [{"name":"subtotal"},{"name":"taxAmount"}],
    [{"name":"totalAmount"},{"name":"costCenter"}],
    [{"name":"paymentStatus"},{"name":"paymentMethod"}],
    [{"name":"paymentDate"},{"name":"deductible"}]
  ]},
  {"label":"Documentos sustentatorios","rows":[
    [{"name":"invoiceFile","fullWidth":true}],
    [{"name":"xmlFile","fullWidth":true}],
    [{"name":"description","fullWidth":true}]
  ]}
]'
request PUT CGasto/layout/detail "$gasto_detail" >/dev/null

gasto_list='[
  {"name":"name","link":true},
  {"name":"issueDate","width":12},
  {"name":"proveedor","width":20},
  {"name":"category","width":15},
  {"name":"totalAmount","width":13},
  {"name":"paymentStatus","width":15},
  {"name":"assignedUser","width":14}
]'
request PUT CGasto/layout/list "$gasto_list" >/dev/null

settings="$(request GET Settings)"
if [[ "$(jq -r '.language' <<<"$settings")" != "es_ES" ]]; then
    request PUT Settings '{"language":"es_ES","timeZone":"America/Lima","dateFormat":"DD/MM/YYYY","timeFormat":"HH:mm"}' >/dev/null
    settings="$(request GET Settings)"
    echo "localized ACME for Peru"
fi

if ! jq -e '.currencyList | index("PEN") != null' <<<"$settings" >/dev/null; then
    currency_list="$(jq -c '.currencyList + ["PEN"] | unique' <<<"$settings")"
    request PUT Settings "$(jq -nc --argjson list "$currency_list" '{currencyList:$list}')" >/dev/null
    settings="$(request GET Settings)"
    echo "enabled PEN currency"
fi

if [[ "$(jq -r '.defaultCurrency' <<<"$settings")" != "PEN" ]]; then
    request PUT Settings '{"defaultCurrency":"PEN"}' >/dev/null
    settings="$(request GET Settings)"
    echo "set PEN as default currency"
fi

# Fixed demonstration rate: 1 PEN = 0.2666667 USD; this data set does not track FX markets.
if [[ "$(request GET CurrencyRate | jq -r '.PEN // empty')" != "0.2666667" ]]; then
    request PUT CurrencyRate '{"PEN":0.2666667}' >/dev/null
    echo "set demo PEN exchange rate"
fi

if [[ "$(jq -r '.tabList | index("CGasto")' <<<"$settings")" != "$(jq -r '.tabList | index("Document") - 1' <<<"$settings")" ]]; then
    tab_list="$(jq -c '[.tabList[] | select(. != "CGasto")] as $tabs | ($tabs | index("Document")) as $at | $tabs[0:$at] + ["CGasto"] + $tabs[$at:]' <<<"$settings")"
    request PUT Settings "$(jq -nc --argjson tabs "$tab_list" '{tabList: $tabs}')" >/dev/null
    echo "added Gastos to navigation"
fi

request POST Admin/rebuild '{}' >/dev/null
echo "ACME operations modules configured."
