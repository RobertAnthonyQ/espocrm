#!/usr/bin/env python3
"""Generate fictional ACME TDR and expense PDFs for the EspoCRM demo."""

from pathlib import Path
from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_RIGHT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import mm
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak, KeepTogether
)

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "output" / "pdf"
OUT.mkdir(parents=True, exist_ok=True)

NAVY = colors.HexColor("#15324B")
BLUE = colors.HexColor("#2A6F97")
CYAN = colors.HexColor("#DCEFF6")
INK = colors.HexColor("#263746")
MUTED = colors.HexColor("#637381")
LINE = colors.HexColor("#D8E1E8")
PALE = colors.HexColor("#F5F8FA")
RED = colors.HexColor("#B42318")

styles = getSampleStyleSheet()
styles.add(ParagraphStyle(name="DocTitle", parent=styles["Title"], fontName="Helvetica-Bold", fontSize=18,
                          leading=22, textColor=NAVY, spaceAfter=8))
styles.add(ParagraphStyle(name="DocSub", parent=styles["Normal"], fontName="Helvetica", fontSize=9,
                          leading=13, textColor=MUTED, spaceAfter=10))
styles.add(ParagraphStyle(name="H1x", parent=styles["Heading1"], fontName="Helvetica-Bold", fontSize=11,
                          leading=14, textColor=NAVY, spaceBefore=8, spaceAfter=5))
styles.add(ParagraphStyle(name="Bodyx", parent=styles["BodyText"], fontName="Helvetica", fontSize=8.8,
                          leading=12.5, textColor=INK, spaceAfter=4))
styles.add(ParagraphStyle(name="Smallx", parent=styles["BodyText"], fontName="Helvetica", fontSize=7.5,
                          leading=10, textColor=MUTED))
styles.add(ParagraphStyle(name="Rightx", parent=styles["BodyText"], fontName="Helvetica", fontSize=8.5,
                          leading=11, alignment=TA_RIGHT, textColor=INK))
styles.add(ParagraphStyle(name="Centerx", parent=styles["BodyText"], fontName="Helvetica-Bold", fontSize=8,
                          leading=10, alignment=TA_CENTER, textColor=RED))
styles.add(ParagraphStyle(name="WhiteHead", parent=styles["BodyText"], fontName="Helvetica-Bold", fontSize=8.5,
                          leading=11, textColor=colors.white))
styles.add(ParagraphStyle(name="WhiteHeadRight", parent=styles["BodyText"], fontName="Helvetica-Bold", fontSize=8.5,
                          leading=11, alignment=TA_RIGHT, textColor=colors.white))


def money(value):
    return f"S/ {value:,.2f}"


def footer(canvas, doc, code):
    canvas.saveState()
    w, h = A4
    canvas.setStrokeColor(LINE)
    canvas.line(18 * mm, 15 * mm, w - 18 * mm, 15 * mm)
    canvas.setFont("Helvetica", 7)
    canvas.setFillColor(MUTED)
    canvas.drawString(18 * mm, 10 * mm, f"ACME Pedidos S.A.C. | {code} | Documento ficticio")
    canvas.drawRightString(w - 18 * mm, 10 * mm, f"Página {doc.page}")
    canvas.restoreState()


def doc_template(path, code):
    return SimpleDocTemplate(str(path), pagesize=A4, rightMargin=18 * mm, leftMargin=18 * mm,
                             topMargin=18 * mm, bottomMargin=22 * mm,
                             title=code, author="ACME Pedidos S.A.C. - Demo")


def title_block(kind, title, code, subtitle):
    brand = Table([
        [Paragraph("<b>ACME</b><br/><font size='7'>PEDIDOS & SERVICIOS</font>", styles["Bodyx"]),
         Paragraph(f"<b>{kind}</b><br/><font size='8'>{code}</font>", styles["Rightx"])],
    ], colWidths=[105 * mm, 65 * mm])
    brand.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), PALE), ("BOX", (0, 0), (-1, -1), 0.7, LINE),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"), ("LEFTPADDING", (0, 0), (-1, -1), 8),
        ("RIGHTPADDING", (0, 0), (-1, -1), 8), ("TOPPADDING", (0, 0), (-1, -1), 8),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 8),
    ]))
    return [brand, Spacer(1, 8 * mm), Paragraph(title, styles["DocTitle"]), Paragraph(subtitle, styles["DocSub"])]


TDRS = [
    dict(file="tdr-001-restaurante-sabor-peruano.pdf", client="Restaurante Sabor Peruano",
         code="TDR-ACME-2026-001", service="Abastecimiento recurrente", value=78000,
         sla="Entrega completa en máximo 24 horas", period="01/01/2026 - 31/12/2026",
         scope="Abastecer insumos secos, bebidas y empaques para tres locales de Lima, con reposición programada y atención de urgencias.",
         deliver=["Catálogo mensual y lista de precios aprobada.", "Dos entregas semanales por local.", "Reporte consolidado de consumo y quiebres de stock."],
         accept="Orden validada, entrega completa, guía firmada y tolerancia máxima de 1% en cantidades."),
    dict(file="tdr-002-hotel-miraflores-plaza.pdf", client="Hotel Miraflores Plaza",
         code="TDR-ACME-2026-002", service="Kits corporativos", value=96500,
         sla="Confirmación en 2 horas y entrega en 48 horas", period="15/01/2026 - 14/01/2027",
         scope="Preparar y distribuir kits de bienvenida, amenities y material para eventos corporativos del hotel.",
         deliver=["Kit estándar con control de lote.", "Personalización para eventos con 72 horas de anticipación.", "Inventario semanal disponible por tipo de kit."],
         accept="Muestra aprobada, empaque sin daños y coincidencia total con la lista nominal del evento."),
    dict(file="tdr-003-cafeteria-andina.pdf", client="Cafetería Andina",
         code="TDR-ACME-2026-003", service="Gestión de pedidos", value=54000,
         sla="Despacho antes de las 07:00 del día siguiente", period="01/02/2026 - 31/01/2027",
         scope="Gestionar pedidos diarios de suministros de cafetería y material descartable para cinco puntos de venta.",
         deliver=["Canal único de pedido y confirmación digital.", "Consolidado semanal por sede.", "Alerta preventiva cuando un producto alcance stock crítico."],
         accept="Entrega dentro de la ventana horaria, productos con vida útil vigente y acta digital por sede."),
    dict(file="tdr-004-mercado-verde-organico.pdf", client="Mercado Verde Orgánico",
         code="TDR-ACME-2026-004", service="Logística y distribución", value=118000,
         sla="95% de entregas en ventana de 2 horas", period="01/03/2026 - 28/02/2027",
         scope="Recoger y distribuir canastas de productores asociados hacia tiendas y clientes institucionales en Lima Metropolitana.",
         deliver=["Plan semanal de rutas.", "Trazabilidad por guía y evidencia de entrega.", "Reporte de incidencias, devoluciones y merma."],
         accept="Trazabilidad completa, evidencia fotográfica y merma mensual menor o igual a 2%."),
    dict(file="tdr-005-clinica-bienestar-integral.pdf", client="Clínica Bienestar Integral",
         code="TDR-ACME-2026-005", service="Cadena de frío", value=156000,
         sla="Temperatura controlada y respuesta crítica en 60 minutos", period="01/04/2026 - 31/03/2027",
         scope="Transportar insumos sensibles con registro continuo de temperatura y protocolo de contingencia.",
         deliver=["Unidad acondicionada y sensor calibrado.", "Reporte de temperatura por traslado.", "Protocolo de contingencia y registro de incidentes."],
         accept="Rango de 2 °C a 8 °C sin interrupciones, sellos íntegros y recepción por personal autorizado."),
    dict(file="tdr-006-universidad-horizonte.pdf", client="Universidad Horizonte",
         code="TDR-ACME-2026-006", service="Servicio integral", value=132000,
         sla="Atención de requerimientos ordinarios en 72 horas", period="15/03/2026 - 14/03/2027",
         scope="Atender requerimientos de materiales para actividades académicas, administrativas y eventos en dos campus.",
         deliver=["Mesa de pedidos con responsables autorizados.", "Despacho clasificado por centro de costo.", "Informe mensual de ejecución presupuestal."],
         accept="Conformidad del área usuaria, identificación presupuestal y entrega documentada en el campus indicado."),
    dict(file="tdr-007-constructora-pacifico.pdf", client="Constructora Pacífico",
         code="TDR-ACME-2026-007", service="Abastecimiento recurrente", value=210000,
         sla="Entrega programada con puntualidad mínima de 96%", period="01/05/2026 - 30/04/2027",
         scope="Abastecer equipos de protección, consumibles y suministros para tres obras activas.",
         deliver=["Matriz de productos homologados.", "Despacho por obra y frente de trabajo.", "Reporte quincenal de consumo, reposición e incidencias."],
         accept="Productos homologados, tallas completas, guía por obra y cero sustituciones sin autorización escrita."),
    dict(file="tdr-008-distribuidora-norte-chico.pdf", client="Distribuidora Norte Chico",
         code="TDR-ACME-2026-008", service="Logística y distribución", value=144000,
         sla="Salida en 24 horas y trazabilidad hasta destino", period="01/06/2026 - 31/05/2027",
         scope="Consolidar y despachar pedidos hacia Huacho, Huaral y Barranca con control de evidencia y devolución.",
         deliver=["Programación de rutas interprovinciales.", "Manifiesto de carga y estado de entrega.", "Liquidación semanal de guías y devoluciones."],
         accept="Entrega íntegra, comprobante firmado y comunicación de incidencia en un máximo de 30 minutos."),
]


def make_tdr(item):
    path = OUT / item["file"]
    doc = doc_template(path, item["code"])
    story = title_block("TÉRMINOS DE REFERENCIA", f"Servicio para {item['client']}", item["code"],
                        "Documento de requerimientos y condiciones de contratación | Versión 1.0")
    data = [["Cliente", item["client"]], ["Servicio", item["service"]], ["Vigencia", item["period"]],
            ["Valor referencial", money(item["value"]) + " (incluye impuestos)"]]
    table = Table([[Paragraph(f"<b>{a}</b>", styles["Bodyx"]), Paragraph(str(b), styles["Bodyx"])] for a, b in data],
                  colWidths=[40 * mm, 130 * mm])
    table.setStyle(TableStyle([("GRID", (0, 0), (-1, -1), .5, LINE), ("BACKGROUND", (0, 0), (0, -1), CYAN),
                               ("VALIGN", (0, 0), (-1, -1), "TOP"), ("LEFTPADDING", (0, 0), (-1, -1), 7),
                               ("RIGHTPADDING", (0, 0), (-1, -1), 7), ("TOPPADDING", (0, 0), (-1, -1), 6),
                               ("BOTTOMPADDING", (0, 0), (-1, -1), 6)]))
    story += [table, Paragraph("1. Antecedentes y objetivo", styles["H1x"]),
              Paragraph("El cliente requiere un proveedor formal que centralice la coordinación, asegure trazabilidad documental y mantenga continuidad operativa. El objetivo es brindar el servicio descrito con control de calidad, tiempos y evidencias verificables.", styles["Bodyx"]),
              Paragraph("2. Alcance", styles["H1x"]), Paragraph(item["scope"], styles["Bodyx"]),
              Paragraph("3. Entregables", styles["H1x"])]
    story += [Paragraph(f"- {x}", styles["Bodyx"]) for x in item["deliver"]]
    story += [Paragraph("4. Niveles de servicio", styles["H1x"]),
              Paragraph(f"Compromiso principal: <b>{item['sla']}</b>. ACME registrará la recepción del pedido, la preparación, el despacho, la entrega y cualquier incidencia. El indicador se calculará mensualmente sobre órdenes cerradas.", styles["Bodyx"]),
              PageBreak(), Paragraph("5. Requisitos del proveedor", styles["H1x"])]
    reqs = ["Personal identificado y capacitado para cada operación.", "Documentos de entrega completos y legibles.",
            "Confidencialidad sobre precios, volúmenes y datos del cliente.", "Plan de continuidad ante indisponibilidad logística.",
            "Cumplimiento de seguridad, calidad y normativa aplicable al servicio."]
    story += [Paragraph(f"- {x}", styles["Bodyx"]) for x in reqs]
    story += [Paragraph("6. Criterios de conformidad", styles["H1x"]), Paragraph(item["accept"], styles["Bodyx"]),
              Paragraph("7. Condiciones comerciales", styles["H1x"]),
              Paragraph("Facturación mensual contra conformidad. Pago a 30 días calendario. Toda variación de alcance, precio o cronograma requiere aprobación escrita del responsable del contrato.", styles["Bodyx"]),
              Paragraph("8. Gobierno y responsables", styles["H1x"])]
    roles = Table([
        [Paragraph("Rol", styles["WhiteHead"]), Paragraph("Responsabilidad", styles["WhiteHead"])],
        [Paragraph("Administrador del cliente", styles["Bodyx"]), Paragraph("Aprueba pedidos, conformidades y cambios de alcance.", styles["Bodyx"])],
        [Paragraph("Ejecutivo de cuenta ACME", styles["Bodyx"]), Paragraph("Coordina la atención y presenta indicadores mensuales.", styles["Bodyx"])],
        [Paragraph("Operaciones ACME", styles["Bodyx"]), Paragraph("Ejecuta, documenta y escala incidentes.", styles["Bodyx"])],
    ], colWidths=[52 * mm, 118 * mm])
    roles.setStyle(TableStyle([("GRID", (0, 0), (-1, -1), .5, LINE), ("BACKGROUND", (0, 0), (-1, 0), NAVY),
                               ("TEXTCOLOR", (0, 0), (-1, 0), colors.white), ("VALIGN", (0, 0), (-1, -1), "TOP"),
                               ("LEFTPADDING", (0, 0), (-1, -1), 7), ("RIGHTPADDING", (0, 0), (-1, -1), 7),
                               ("TOPPADDING", (0, 0), (-1, -1), 6), ("BOTTOMPADDING", (0, 0), (-1, -1), 6)]))
    story += [roles, Spacer(1, 9 * mm), Paragraph("DOCUMENTO FICTICIO PARA DEMOSTRACIÓN - NO CONSTITUYE CONTRATO", styles["Centerx"])]
    doc.build(story, onFirstPage=lambda c, d: footer(c, d, item["code"]),
              onLaterPages=lambda c, d: footer(c, d, item["code"]))


EXPENSES = [
    dict(file="gasto-001-empaques-lima-eco.pdf", supplier="Empaques Lima Eco", ruc="20999991001",
         number="F001-0831", date="12/08/2026", due="11/09/2026", concept="Cajas kraft, bolsas compostables y etiquetas", subtotal=4720.00),
    dict(file="gasto-002-logistica-rapida.pdf", supplier="Logística Rápida", ruc="20999991002",
         number="F001-1842", date="15/08/2026", due="14/09/2026", concept="Servicio de reparto urbano - julio 2026", subtotal=3200.00),
    dict(file="gasto-003-friotech.pdf", supplier="FríoTech", ruc="20999991003",
         number="FT01-0098", date="18/08/2026", due="17/09/2026", concept="Mantenimiento preventivo de unidad refrigerada", subtotal=8500.00),
    dict(file="gasto-004-alimentos-del-valle.pdf", supplier="Alimentos del Valle", ruc="20999991004",
         number="F002-0441", date="20/08/2026", due="19/09/2026", concept="Insumos alimentarios secos - lote agosto", subtotal=12600.00),
    dict(file="gasto-005-logistica-ruta-norte.pdf", supplier="Logística Rápida", ruc="20999991002",
         number="F001-1865", date="25/08/2026", due="24/09/2026", concept="Distribución interprovincial ruta Norte Chico", subtotal=5980.00),
    dict(file="gasto-006-empaques-kits.pdf", supplier="Empaques Lima Eco", ruc="20999991001",
         number="F001-0856", date="28/08/2026", due="27/09/2026", concept="Empaques personalizados para kits corporativos", subtotal=7350.00),
]


def make_invoice(item):
    path = OUT / item["file"]
    code = item["number"]
    doc = doc_template(path, code)
    tax = round(item["subtotal"] * .18, 2)
    total = item["subtotal"] + tax
    story = title_block("FACTURA ELECTRÓNICA", item["supplier"], code,
                        f"RUC {item['ruc']} | Representación impresa ficticia")
    parties = Table([
        [Paragraph("<b>Proveedor</b>", styles["Bodyx"]), Paragraph(item["supplier"], styles["Bodyx"]),
         Paragraph("<b>Emisión</b>", styles["Bodyx"]), Paragraph(item["date"], styles["Bodyx"])],
        [Paragraph("<b>Cliente</b>", styles["Bodyx"]), Paragraph("ACME Pedidos S.A.C.", styles["Bodyx"]),
         Paragraph("<b>Vencimiento</b>", styles["Bodyx"]), Paragraph(item["due"], styles["Bodyx"])],
        [Paragraph("<b>RUC cliente</b>", styles["Bodyx"]), Paragraph("20999990001", styles["Bodyx"]),
         Paragraph("<b>Moneda</b>", styles["Bodyx"]), Paragraph("PEN", styles["Bodyx"])],
    ], colWidths=[29 * mm, 66 * mm, 31 * mm, 44 * mm])
    parties.setStyle(TableStyle([("GRID", (0, 0), (-1, -1), .5, LINE), ("BACKGROUND", (0, 0), (0, -1), CYAN),
                                  ("BACKGROUND", (2, 0), (2, -1), CYAN), ("VALIGN", (0, 0), (-1, -1), "TOP"),
                                  ("LEFTPADDING", (0, 0), (-1, -1), 6), ("RIGHTPADDING", (0, 0), (-1, -1), 6),
                                  ("TOPPADDING", (0, 0), (-1, -1), 7), ("BOTTOMPADDING", (0, 0), (-1, -1), 7)]))
    story += [parties, Spacer(1, 10 * mm)]
    rows = [[Paragraph("Cant.", styles["WhiteHead"]), Paragraph("Descripción", styles["WhiteHead"]),
             Paragraph("Valor unit.", styles["WhiteHeadRight"]), Paragraph("Importe", styles["WhiteHeadRight"])],
            [Paragraph("1", styles["Bodyx"]), Paragraph(item["concept"], styles["Bodyx"]),
             Paragraph(money(item["subtotal"]), styles["Rightx"]), Paragraph(money(item["subtotal"]), styles["Rightx"])]]
    detail = Table(rows, colWidths=[18 * mm, 92 * mm, 30 * mm, 30 * mm], rowHeights=[10 * mm, 22 * mm])
    detail.setStyle(TableStyle([("GRID", (0, 0), (-1, -1), .5, LINE), ("BACKGROUND", (0, 0), (-1, 0), NAVY),
                                ("TEXTCOLOR", (0, 0), (-1, 0), colors.white), ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                                ("LEFTPADDING", (0, 0), (-1, -1), 6), ("RIGHTPADDING", (0, 0), (-1, -1), 6)]))
    totals = Table([
        [Paragraph("Subtotal", styles["Rightx"]), Paragraph(money(item["subtotal"]), styles["Rightx"])],
        [Paragraph("IGV (18%)", styles["Rightx"]), Paragraph(money(tax), styles["Rightx"])],
        [Paragraph("<b>Total</b>", styles["Rightx"]), Paragraph(f"<b>{money(total)}</b>", styles["Rightx"])],
    ], colWidths=[35 * mm, 35 * mm], hAlign="RIGHT")
    totals.setStyle(TableStyle([("GRID", (0, 0), (-1, -1), .5, LINE), ("BACKGROUND", (0, -1), (-1, -1), CYAN),
                                ("LEFTPADDING", (0, 0), (-1, -1), 7), ("RIGHTPADDING", (0, 0), (-1, -1), 7),
                                ("TOPPADDING", (0, 0), (-1, -1), 7), ("BOTTOMPADDING", (0, 0), (-1, -1), 7)]))
    story += [detail, Spacer(1, 4 * mm), totals, Spacer(1, 12 * mm),
              Paragraph("Condición de pago", styles["H1x"]),
              Paragraph("Transferencia bancaria a 30 días. La conformidad del servicio y el registro del comprobante en el CRM son requisitos para programación de pago.", styles["Bodyx"]),
              Spacer(1, 18 * mm), Paragraph("DOCUMENTO FICTICIO - SIN VALIDEZ TRIBUTARIA", styles["Centerx"]),
              Paragraph("Creado exclusivamente como dato de demostración de ACME Pedidos S.A.C. No corresponde a una operación real ni reemplaza un comprobante autorizado por SUNAT.", styles["Smallx"])]
    doc.build(story, onFirstPage=lambda c, d: footer(c, d, code), onLaterPages=lambda c, d: footer(c, d, code))


for tdr in TDRS:
    make_tdr(tdr)
for expense in EXPENSES:
    make_invoice(expense)

print(f"Generated {len(TDRS) + len(EXPENSES)} PDFs in {OUT}")
