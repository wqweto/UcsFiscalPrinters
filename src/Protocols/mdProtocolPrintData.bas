Attribute VB_Name = "mdProtocolPrintData"
'=========================================================================
'
' UcsFP20 (c) 2008-2019 by Unicontsoft
'
' Unicontsoft Fiscal Printers Component 2.0
'
' This project is licensed under the terms of the MIT license
' See the LICENSE file in the project root for more information
'
'=========================================================================
'
' Protocol's print data functions
'
'=========================================================================
Option Explicit
DefObj A-Z
Private Const MODULE_NAME As String = "mdProtocolPrintData"

'=========================================================================
' Public Enums
'=========================================================================

Public Enum UcsPpdInvDataIndex
    ucsInvDocNo
    ucsInvCgTaxNo
    ucsInvCgVatNo
    ucsInvCgName
    ucsInvCgCity
    ucsInvCgAddress
    ucsInvCgPrsReceive
    ucsInvCgTaxNoType
End Enum

Public Enum UcsPpdRevDataIndex
    ucsRevType
    ucsRevReceiptNo
    ucsRevReceiptDate
    ucsRevFiscalMemoryNo
    ucsRevInvoiceNo
    ucsRevReason
End Enum

Public Enum UcsPpdOwnDataIndex
    ucsOwnName
    ucsOwnAddress
    ucsOwnBulstat
    ucsOwnDepName
    ucsOwnDepAddress
    ucsOwnFooter1
    ucsOwnFooter2
End Enum

Public Enum UcsPpdRowTypeEnum
    ucsRowInit = 1
    ucsRowPlu
    ucsRowLine
    ucsRowDiscount
    ucsRowPayment
End Enum

'=========================================================================
' Public Types
'=========================================================================

Public Type UcsPpdRowData
    RowType             As UcsPpdRowTypeEnum
    InitReceiptType     As UcsFiscalReceiptTypeEnum
    InitOperatorCode    As String
    InitOperatorName    As String
    InitOperatorPassword As String
    InitUniqueSaleNo    As String
    InitInvData         As Variant
    InitRevData         As Variant
    PluName             As String
    PluPrice            As Double
    PluQuantity         As Double
    PluTaxGroup         As Long
    LineText            As String
    LineCommand         As String
    LineWordWrap        As Boolean
    DiscType            As UcsFiscalDiscountTypeEnum
    DiscValue           As Double
    PmtType             As UcsFiscalPaymentTypeEnum
    PmtName             As String
    PmtAmount           As Double
    PrintRowType        As UcsFiscalReceiptTypeEnum
End Type

Public Type UcsPpdExecuteContext
    GrpTotal(1 To 8)    As Double
    Paid                As Double
    PluCount            As Long
    PmtPrinted          As Boolean
    ChangePrinted       As Boolean
    Row                 As Long
End Type

Public Type UcsPpdConfigValues
    RowChars            As Long
    ItemChars           As Long
    AbsoluteDiscount    As Boolean
    NegativePrices      As Boolean
    MinDiscount         As Double
    MaxDiscount         As Double
    MaxReceiptRows      As Long
End Type

Public Type UcsPpdLocalizedTexts
    ErrNoReceiptStarted As String
    TxtSurcharge        As String
    TxtDiscount         As String
    TxtPluSales         As String
End Type

Public Type UcsProtocolPrintData
    Row()               As UcsPpdRowData
    RowCount            As Long
    ExecCtx             As UcsPpdExecuteContext
    LastError           As String
    LastErrNo           As UcsFiscalErrorsEnum
    Config              As UcsPpdConfigValues
    LocalizedText       As UcsPpdLocalizedTexts
End Type

Private Const ERR_NO_RECEIPT_STARTED    As String = "No receipt started"
Private Const TXT_SURCHARGE             As String = "Surcharge %1"
Private Const TXT_DISCOUNT              As String = "Discount %1"
Private Const TXT_PLUSALES              As String = "Sales %1"
Public Const ucsFscDscPluAbs            As Long = ucsFscDscPlu + 100
Public Const ucsFscDscSubtotalAbs       As Long = ucsFscDscSubtotal + 100
Public Const ucsFscRcpNonfiscal         As Long = ucsFscRcpSale + 100

'=========================================================================
' Error handling
'=========================================================================

Private Sub RaiseError(sFunc As String)
    Debug.Print MODULE_NAME & "." & sFunc & ": " & Err.Description
    OutputDebugLog MODULE_NAME, sFunc & "(" & Erl & ")", "Run-time error: " & Err.Description
    Err.Raise Err.Number, MODULE_NAME & "." & sFunc & "(" & Erl & ")" & vbCrLf & Err.Source, Err.Description
End Sub

'=========================================================================
' Functions
'=========================================================================

Public Function PpdStartReceipt( _
            uData As UcsProtocolPrintData, _
            ByVal ReceiptType As UcsFiscalReceiptTypeEnum, _
            Optional OperatorCode As String, _
            Optional OperatorName As String, _
            Optional OperatorPassword As String, _
            Optional UniqueSaleNo As String, _
            Optional InvDocNo As String, _
            Optional InvCgTaxNo As String, _
            Optional ByVal InvCgTaxNoType As UcsFiscalTaxNoTypeEnum, _
            Optional InvCgVatNo As String, _
            Optional InvCgName As String, _
            Optional InvCgCity As String, _
            Optional InvCgAddress As String, _
            Optional InvCgPrsReceive As String, _
            Optional ByVal RevType As UcsFiscalReversalTypeEnum, _
            Optional RevReceiptNo As String, _
            Optional RevReceiptDate As Date, _
            Optional RevFiscalMemoryNo As String, _
            Optional RevInvoiceNo As String, _
            Optional RevReason As String) As Boolean
    Const FUNC_NAME     As String = "PpdStartReceipt"
    Dim uCtxEmpty       As UcsPpdExecuteContext
    Dim sCity           As String
    Dim sAddress        As String

    On Error GoTo EH
    uData.ExecCtx = uCtxEmpty
    ReDim uData.Row(0 To 10) As UcsPpdRowData
    uData.RowCount = 0
    With uData.Row(pvAddRow(uData))
        .RowType = ucsRowInit
        .InitReceiptType = LimitLong(ReceiptType, 1, [_ucsFscRcpMax] - 1)
        .InitOperatorCode = SafeText(OperatorCode)
        .InitOperatorName = SafeText(OperatorName)
        .InitOperatorPassword = SafeText(OperatorPassword)
        .InitUniqueSaleNo = SafeText(UniqueSaleNo)
        SplitCgAddress Trim$(SafeText(InvCgCity)) & vbCrLf & Trim$(SafeText(InvCgAddress)), sCity, sAddress, pvCommentChars(uData)
        .InitInvData = Array(SafeText(InvDocNo), SafeText(InvCgTaxNo), SafeText(InvCgVatNo), _
            SafeText(InvCgName), sCity, sAddress, SafeText(InvCgPrsReceive), InvCgTaxNoType)
        .InitRevData = Array(IIf(.InitReceiptType = ucsFscRcpCreditNote, ucsFscRevTaxBaseReduction, RevType), _
            SafeText(RevReceiptNo), RevReceiptDate, SafeText(RevFiscalMemoryNo), SafeText(RevInvoiceNo), SafeText(RevReason))
    End With
    '--- success
    PpdStartReceipt = True
    Exit Function
EH:
    RaiseError FUNC_NAME
End Function

Public Function PpdAddPLU( _
            uData As UcsProtocolPrintData, _
            Name As String, _
            ByVal Price As Double, _
            Optional ByVal Quantity As Double = 1, _
            Optional ByVal TaxGroup As Long = 2, _
            Optional ByVal BeforeIndex As Long) As Boolean
    Const FUNC_NAME     As String = "PpdAddPLU"
    Dim uRow            As UcsPpdRowData
    Dim bNegative       As Boolean

    On Error GoTo EH
    '--- sanity check
    If uData.RowCount = 0 Then
        pvSetLastError uData, Zn(uData.LocalizedText.ErrNoReceiptStarted, ERR_NO_RECEIPT_STARTED)
        GoTo QH
    End If
    With uRow
        .RowType = ucsRowPlu
        .PluName = RTrim$(SafeText(Name))
        Select Case uData.Row(0).InitReceiptType
        Case ucsFscRcpReversal, ucsFscRcpCreditNote
            If Price < 0 Then
                Price = -Price
            Else
                Quantity = -Quantity
            End If
        End Select
        bNegative = (Round(Price, 2) * Round(Quantity, 3) < -DBL_EPSILON)
        .PluPrice = IIf(bNegative, -1, 1) * Round(Abs(Price), 2)
        .PluQuantity = Round(IIf(bNegative Or uData.Config.NegativePrices, Abs(Quantity), Quantity), 3)
        .PluTaxGroup = LimitLong(TaxGroup, 1, 8)
        .PrintRowType = uData.Row(0).InitReceiptType
    End With
    pvInsertRow uData, BeforeIndex, uRow
    '--- success
    PpdAddPLU = True
QH:
    Exit Function
EH:
    RaiseError FUNC_NAME
End Function

Public Function PpdAddLine( _
            uData As UcsProtocolPrintData, _
            Line As String, _
            Optional ByVal WordWrap As Boolean, _
            Optional ByVal BeforeIndex As Long) As Boolean
    Const FUNC_NAME     As String = "PpdAddLine"
    Dim uRow            As UcsPpdRowData

    On Error GoTo EH
    '--- sanity check
    If uData.RowCount = 0 Then
        pvSetLastError uData, Zn(uData.LocalizedText.ErrNoReceiptStarted, ERR_NO_RECEIPT_STARTED)
        GoTo QH
    End If
    With uRow
        .RowType = ucsRowLine
        .LineText = RTrim$(SafeText(Line))
        .LineWordWrap = WordWrap
        .PrintRowType = uData.Row(0).InitReceiptType
    End With
    pvInsertRow uData, BeforeIndex, uRow
    '--- success
    PpdAddLine = True
QH:
    Exit Function
EH:
    RaiseError FUNC_NAME
End Function

Public Function PpdAddDiscount( _
            uData As UcsProtocolPrintData, _
            ByVal DiscType As UcsFiscalDiscountTypeEnum, _
            ByVal Value As Double, _
            Optional ByVal BeforeIndex As Long) As Boolean
    Const FUNC_NAME     As String = "PpdAddDiscount"
    Dim uRow            As UcsPpdRowData
    Dim lIdx            As Long

    On Error GoTo EH
    '--- sanity check
    If uData.RowCount = 0 Then
        pvSetLastError uData, Zn(uData.LocalizedText.ErrNoReceiptStarted, ERR_NO_RECEIPT_STARTED)
        GoTo QH
    End If
    Select Case DiscType
    Case ucsFscDscTotal
        PpdAddPLU uData, Printf(IIf(Value > DBL_EPSILON, Zn(uData.LocalizedText.TxtSurcharge, TXT_SURCHARGE), Zn(uData.LocalizedText.TxtDiscount, TXT_DISCOUNT)), vbNullString), Value, BeforeIndex:=BeforeIndex
    Case ucsFscDscPlu
        For lIdx = IIf(BeforeIndex <> 0, BeforeIndex, uData.RowCount) - 1 To 0 Step -1
            With uData.Row(lIdx)
                If .RowType = ucsRowPlu Then
                    .DiscType = DiscType
                    .DiscValue = Round(Value, 2)
                    Exit For
                End If
            End With
        Next
    Case Else
        With uRow
            .RowType = ucsRowDiscount
            .DiscType = DiscType
            .DiscValue = Round(Value, 2)
            .PrintRowType = uData.Row(0).InitReceiptType
        End With
        pvInsertRow uData, BeforeIndex, uRow
    End Select
    '--- success
    PpdAddDiscount = True
QH:
    Exit Function
EH:
    RaiseError FUNC_NAME
End Function

Public Function PpdAddPayment( _
            uData As UcsProtocolPrintData, _
            ByVal Number As UcsFiscalPaymentTypeEnum, _
            Name As String, _
            ByVal Amount As Double) As Boolean
    Const FUNC_NAME     As String = "PpdAddPayment"

    On Error GoTo EH
    '--- sanity check
    If uData.RowCount = 0 Then
        pvSetLastError uData, Zn(uData.LocalizedText.ErrNoReceiptStarted, ERR_NO_RECEIPT_STARTED)
        GoTo QH
    End If
    If Number < 0 Then
        '--- custom payment types: 5, 6, 7 & 8
        Number = 4 - Number
    End If
    With uData.Row(pvAddRow(uData))
        .RowType = ucsRowPayment
        .PmtType = LimitLong(Number, 1, 8)
        .PmtName = SafeText(Name)
        .PmtAmount = Round(Amount, 2)
        .PrintRowType = uData.Row(0).InitReceiptType
        Select Case .PrintRowType
        Case ucsFscRcpReversal, ucsFscRcpCreditNote
            .PmtAmount = -.PmtAmount
        End Select
    End With
    '--- success
    PpdAddPayment = True
QH:
    Exit Function
EH:
    RaiseError FUNC_NAME
End Function

Public Function PpdEndReceipt( _
            uData As UcsProtocolPrintData, _
            sResumeTicket As String) As Boolean
    Const FUNC_NAME     As String = "PpdEndReceipt"
    Dim vSplit          As Variant
    Dim lIdx            As Long
    Dim lPos            As Long

    On Error GoTo EH
    '--- sanity check
    If uData.RowCount = 0 Then
        pvSetLastError uData, Zn(uData.LocalizedText.ErrNoReceiptStarted, ERR_NO_RECEIPT_STARTED)
        GoTo QH
    End If
    '--- restore context
    vSplit = Split(sResumeTicket, STR_CHR1)
    With uData.ExecCtx
        For lIdx = LBound(.GrpTotal) To UBound(.GrpTotal)
            .GrpTotal(lIdx) = C_Dbl(At(vSplit, lPos)): lPos = lPos + 1
        Next
        .Paid = C_Dbl(At(vSplit, lPos)): lPos = lPos + 1
        .PluCount = C_Lng(At(vSplit, lPos)): lPos = lPos + 1
        .PmtPrinted = C_Bool(At(vSplit, lPos)): lPos = lPos + 1
        .ChangePrinted = C_Bool(At(vSplit, lPos)): lPos = lPos + 1
        .Row = C_Lng(At(vSplit, lPos)): lPos = lPos + 1
    End With
    '--- fix fiscal receipts with for more than uData.MaxReceiptRows PLUs
    pvConvertExtraRows uData
    '--- append final payment (total)
    With uData.Row(pvAddRow(uData))
        .RowType = ucsRowPayment
        .PrintRowType = uData.Row(0).InitReceiptType
    End With
    '--- success
    PpdEndReceipt = True
QH:
    Exit Function
EH:
    RaiseError FUNC_NAME
End Function

Public Function PpdGetResumeTicket(uData As UcsProtocolPrintData) As String
    Const FUNC_NAME     As String = "PpdGetResumeTicket"
    Dim lIdx            As Long

    On Error GoTo EH
    '--- sanity check
    If uData.RowCount = 0 Then
        pvSetLastError uData, Zn(uData.LocalizedText.ErrNoReceiptStarted, ERR_NO_RECEIPT_STARTED)
        GoTo QH
    End If
    '--- need resume ticket only if payment processed
    With uData.ExecCtx
        If .PmtPrinted Then
            For lIdx = LBound(.GrpTotal) To UBound(.GrpTotal)
                PpdGetResumeTicket = PpdGetResumeTicket & .GrpTotal(lIdx) & STR_CHR1
            Next
            PpdGetResumeTicket = PpdGetResumeTicket & .Paid & STR_CHR1 & .PluCount & STR_CHR1 & -.PmtPrinted & STR_CHR1 & -.ChangePrinted & STR_CHR1 & .Row
        End If
    End With
QH:
    Exit Function
EH:
    RaiseError FUNC_NAME
End Function

Private Function pvAddRow(uData As UcsProtocolPrintData) As Long
    Const FUNC_NAME     As String = "pvAddRow"

    On Error GoTo EH
    If uData.RowCount > UBound(uData.Row) Then
        ReDim Preserve uData.Row(0 To 2 * UBound(uData.Row)) As UcsPpdRowData
    End If
    pvAddRow = uData.RowCount
    uData.RowCount = uData.RowCount + 1
    Exit Function
EH:
    RaiseError FUNC_NAME
End Function

Private Sub pvInsertRow(uData As UcsProtocolPrintData, ByVal lRow As Long, uRow As UcsPpdRowData)
    Const FUNC_NAME     As String = "pvInsertRow"
    Dim lIdx            As Long

    On Error GoTo EH
    If lRow = 0 Or lRow >= uData.RowCount Then
        uData.Row(pvAddRow(uData)) = uRow
    Else
        '--- shift rows down and insert new row
        For lIdx = pvAddRow(uData) To lRow + 1 Step -1
            uData.Row(lIdx) = uData.Row(lIdx - 1)
        Next
        uData.Row(lRow) = uRow
    End If
    Exit Sub
EH:
    RaiseError FUNC_NAME
End Sub

Private Sub pvSetLastError(uData As UcsProtocolPrintData, sError As String, Optional ByVal ErrNum As UcsFiscalErrorsEnum = -1)
    If ErrNum < 0 Then
        uData.LastErrNo = IIf(LenB(sError) = 0, ucsFerNone, ucsFerGeneralError)
    Else
        uData.LastErrNo = ErrNum
    End If
    uData.LastError = sError
End Sub

Private Sub pvConvertExtraRows(uData As UcsProtocolPrintData)
    Const FUNC_NAME     As String = "pvConvertExtraRows"
    Dim uCtx            As UcsPpdExecuteContext
    Dim lIdx            As Long
    Dim lRow            As Long
    Dim lCount          As Long
    Dim lTotal          As Long
    Dim dblTotal        As Double
    Dim uSum            As UcsPpdExecuteContext
    Dim dblDiscount     As Double
    Dim dblDiscTotal    As Double
    Dim dblPrice        As Double
    Dim vSplit          As Variant

    On Error GoTo EH
    '--- convert out-of-range discounts to PLU rows
    '--- note: uData.RowCount may change in loop on PpdAddPLU
    Do While lRow < uData.RowCount
        '--- note: 'With' locks uData.Row array and fails if auto-grow needed in PpdAddPLU
'        With uData.Row(lRow)
            If uData.Row(lRow).RowType = ucsRowPlu Then
                dblPrice = uData.Row(lRow).PluPrice
                dblTotal = Round(uData.Row(lRow).PluQuantity * dblPrice, 2)
                dblDiscTotal = Round(dblTotal * uData.Row(lRow).DiscValue / 100#, 2)
                If Not uData.Config.NegativePrices And dblPrice <= 0 Then
                    vSplit = WrapText(uData.Row(lRow).PluName, uData.Config.ItemChars)
                    lIdx = LimitLong(UBound(vSplit), , 1)
                    vSplit(lIdx) = AlignText(vSplit(lIdx), SafeFormat(dblTotal + dblDiscTotal, "0.00") & " " & Chr$(191 + uData.Row(lRow).PluTaxGroup), pvCommentChars(uData))
                    uData.Row(lRow).RowType = ucsRowLine
                    uData.Row(lRow).LineText = vSplit(0)
                    If lIdx > 0 Then
                        PpdAddLine uData, At(vSplit, 1), False, lRow + 1
                        lRow = lRow + 1
                    ElseIf lIdx = 0 And uData.Row(lRow).PluQuantity <> 1 Then
                        PpdAddLine uData, AlignText(vbNullString, SafeFormat(uData.Row(lRow).PluQuantity, "0.000") & " x " & SafeFormat(uData.Row(lRow).PluPrice, "0.00"), pvCommentChars(uData) - 2), False, lRow
                    End If
                    If dblPrice < -DBL_EPSILON Then
                        PpdAddDiscount uData, ucsFscDscSubtotalAbs, dblTotal + dblDiscTotal, lRow + 1
                    End If
                ElseIf (uData.Row(lRow).DiscValue < uData.Config.MinDiscount Or uData.Row(lRow).DiscValue > uData.Config.MaxDiscount) Then
                    dblDiscount = Limit(uData.Row(lRow).DiscValue, uData.Config.MinDiscount, uData.Config.MaxDiscount)
                    If uData.Config.AbsoluteDiscount Then
                        uData.Row(lRow).DiscType = ucsFscDscPluAbs
                        uData.Row(lRow).DiscValue = dblDiscTotal
                    ElseIf dblDiscTotal = Round(dblTotal * dblDiscount / 100#, 2) Then
                        uData.Row(lRow).DiscValue = dblDiscount
                    Else
                        dblDiscount = uData.Row(lRow).DiscValue
                        uData.Row(lRow).DiscType = 0
                        uData.Row(lRow).DiscValue = 0
                        PpdAddPLU uData, Printf(IIf(dblDiscTotal > DBL_EPSILON, Zn(uData.LocalizedText.TxtSurcharge, TXT_SURCHARGE), Zn(uData.LocalizedText.TxtDiscount, TXT_DISCOUNT)), SafeFormat(Abs(dblDiscount), "0.00") & " %"), _
                            dblDiscTotal, 1, uData.Row(lRow).PluTaxGroup, lRow + 1
                    End If
                ElseIf uData.Row(lRow).DiscType = ucsFscDscPlu And dblPrice < -DBL_EPSILON Then
                    '--- convert PLU discount on void rows
                    If uData.Config.AbsoluteDiscount Then
                        uData.Row(lRow).DiscType = ucsFscDscPluAbs
                        uData.Row(lRow).DiscValue = dblDiscTotal
                    Else
                        dblDiscount = uData.Row(lRow).DiscValue
                        uData.Row(lRow).DiscType = 0
                        uData.Row(lRow).DiscValue = 0
                        PpdAddPLU uData, Printf(IIf(dblTotal * dblDiscount > DBL_EPSILON, Zn(uData.LocalizedText.TxtSurcharge, TXT_SURCHARGE), Zn(uData.LocalizedText.TxtDiscount, TXT_DISCOUNT)), SafeFormat(Abs(dblDiscount), "0.00") & " %"), _
                                dblDiscTotal, 1, uData.Row(lRow).PluTaxGroup, lRow + 1
                    End If
                End If
            ElseIf uData.Row(lRow).RowType = ucsRowDiscount Then
                If (uData.Row(lRow).DiscValue < uData.Config.MinDiscount Or uData.Row(lRow).DiscValue > uData.Config.MaxDiscount) And uData.Row(lRow).DiscType = ucsFscDscSubtotal Then
                    pvGetSubtotals uData, lRow, uSum
                    dblDiscount = Limit(uData.Row(lRow).DiscValue, uData.Config.MinDiscount, uData.Config.MaxDiscount)
                    lCount = 0
                    For lIdx = 1 To UBound(uSum.GrpTotal)
                        If Round(uSum.GrpTotal(lIdx) * uData.Row(lRow).DiscValue / 100#, 2) <> Round(uSum.GrpTotal(lIdx) * dblDiscount / 100#, 2) Then
                            lCount = lCount + 1
                        End If
                    Next
                    If lCount = 0 Then
                        uData.Row(lRow).DiscValue = dblDiscount
                    Else
                        dblDiscount = uData.Row(lRow).DiscValue
                        uData.Row(lRow).DiscValue = 0
                        For lIdx = UBound(uSum.GrpTotal) To 1 Step -1
                            If Abs(uSum.GrpTotal(lIdx)) > DBL_EPSILON Then
                                PpdAddPLU uData, Printf(IIf(uSum.GrpTotal(lIdx) * dblDiscount > DBL_EPSILON, Zn(uData.LocalizedText.TxtSurcharge, TXT_SURCHARGE), Zn(uData.LocalizedText.TxtDiscount, TXT_DISCOUNT)), SafeFormat(Abs(dblDiscount), "0.00") & " %"), _
                                    Round(uSum.GrpTotal(lIdx) * dblDiscount / 100#, 2), 1, lIdx, lRow + 1
                            End If
                        Next
                    End If
                End If
            End If
'        End With
        lRow = lRow + 1
    Loop
    '--- count PLU rows and mark different VAT groups
    lCount = 0
    For lRow = 0 To uData.RowCount - 1
        With uData.Row(lRow)
            If .RowType = ucsRowPlu Then
                lCount = lCount + 1
                uCtx.GrpTotal(.PluTaxGroup) = 1
            End If
        End With
    Next
    If lCount > uData.Config.MaxReceiptRows Then
        '--- count different VAT groups in PLUs
        For lRow = 1 To UBound(uCtx.GrpTotal)
            If Abs(uCtx.GrpTotal(lRow)) > DBL_EPSILON Then
                lTotal = lTotal + 1
                uCtx.GrpTotal(lRow) = 0
            End If
        Next
        '--- set extra rows to nonfiscal printing and calc GrpTotal by VAT groups
        lCount = 0
        For lRow = 0 To uData.RowCount - 1
            With uData.Row(lRow)
                If .RowType = ucsRowPlu Then
                    lCount = lCount + 1
                    If lCount > uData.Config.MaxReceiptRows - lTotal Then
                        .PrintRowType = ucsFscRcpNonfiscal
                        dblTotal = Round(.PluQuantity * .PluPrice, 2)
                        If .DiscType = ucsFscDscPlu Then
                            dblTotal = Round(dblTotal + Round(dblTotal * .DiscValue / 100#, 2), 2)
                        ElseIf .DiscType = ucsFscDscPluAbs Then
                            dblTotal = Round(dblTotal + .DiscValue, 2)
                        End If
                        If .PluTaxGroup > 0 Then
                            uCtx.GrpTotal(.PluTaxGroup) = Round(uCtx.GrpTotal(.PluTaxGroup) + dblTotal, 2)
                        End If
                    End If
                ElseIf .RowType = ucsRowDiscount And .DiscType = ucsFscDscSubtotal Then
                    If lCount > uData.Config.MaxReceiptRows - lTotal Then
                        .PrintRowType = ucsFscRcpNonfiscal
                        pvGetSubtotals uData, lRow, uSum
                        For lIdx = 1 To UBound(uCtx.GrpTotal)
                            uCtx.GrpTotal(lIdx) = Round(uCtx.GrpTotal(lIdx) + Round(uSum.GrpTotal(lIdx) * .DiscValue / 100#, 2), 2)
                        Next
                    End If
                End If
            End With
        Next
        '--- find first payment row
        For lRow = 0 To uData.RowCount - 1
            If uData.Row(lRow).RowType = ucsRowPayment Then
                Exit For
            End If
        Next
        '--- append fiscal rows for GrpTotal by VAT groups
        For lIdx = 1 To UBound(uCtx.GrpTotal)
            If Abs(uCtx.GrpTotal(lIdx)) > DBL_EPSILON Then
                PpdAddPLU uData, Printf(Zn(uData.LocalizedText.TxtPluSales, TXT_PLUSALES), Chr$(191 + lIdx)), uCtx.GrpTotal(lIdx), 1, lIdx, lRow
                lRow = lRow + 1
            End If
        Next
    End If
    Exit Sub
EH:
    RaiseError FUNC_NAME
End Sub

Private Sub pvGetSubtotals(uData As UcsProtocolPrintData, ByVal lRow As Long, uCtx As UcsPpdExecuteContext)
    Const FUNC_NAME     As String = "pvGetSubtotals"
    Dim lIdx            As Long
    Dim lJdx            As Long
    Dim dblTotal        As Double
    Dim uEmpty          As UcsPpdExecuteContext

    On Error GoTo EH
    uCtx = uEmpty
    For lIdx = 0 To lRow - 1
        With uData.Row(lIdx)
        If .RowType = ucsRowPlu Then
            dblTotal = Round(.PluQuantity * .PluPrice, 2)
            Select Case .DiscType
            Case ucsFscDscPlu
                dblTotal = Round(dblTotal + Round(dblTotal * .DiscValue / 100#, 2), 2)
            Case ucsFscDscPluAbs
                dblTotal = Round(dblTotal + .DiscValue, 2)
            End Select
            If .PluTaxGroup > 0 Then
                uCtx.GrpTotal(.PluTaxGroup) = Round(uCtx.GrpTotal(.PluTaxGroup) + dblTotal, 2)
            End If
        ElseIf .RowType = ucsRowDiscount Then
            Select Case .DiscType
            Case ucsFscDscSubtotal
                For lJdx = 1 To UBound(uCtx.GrpTotal)
                    dblTotal = Round(uCtx.GrpTotal(lJdx) * .DiscValue / 100#, 2)
                    uCtx.GrpTotal(lJdx) = Round(uCtx.GrpTotal(lJdx) + dblTotal, 2)
                Next
            Case ucsFscDscSubtotalAbs
                For lJdx = 1 To UBound(uCtx.GrpTotal)
                    If Abs(uCtx.GrpTotal(lJdx)) > DBL_EPSILON Then
                        uCtx.GrpTotal(lJdx) = Round(uCtx.GrpTotal(lJdx) - .DiscValue, 2)
                        Exit For
                    End If
                Next
            End Select
        End If
        End With
    Next
    Exit Sub
EH:
    RaiseError FUNC_NAME
End Sub

Private Property Get pvCommentChars(uData As UcsProtocolPrintData) As Long
    pvCommentChars = uData.Config.RowChars - 2
End Property