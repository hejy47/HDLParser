# class of hdl
# from hdlConvertor

ALL_BASE_CLASSES = [
    "iHdlObj",
    "iHdlObjWithName",
    "iHdlObjInModule",
    "iHdlStatement"
]

ALL_TYPEDEF_CLASSES = [
    "HdlTypeBitsDef",
    "HdlClassType",
    "HdlClassDef",
    "HdlPhysicalDef",
    "HdlEnumDef",
    "HdlFunctionDef"
]

ALL_STUCTURAL_CLASSES = [
    "HdlLibrary",
    "HdlValueIdspace",
    "HdlModuleDec",
    "HdlModuleDef",
    "HdlContext"
]

ALL_STATEMENT_CLASSES = [
    "HdlStmNop",
    "HdlStmBlock",
    "HdlStmAssign",
    "HdlStmIf",
    "HdlStmProcess",
    "HdlStmCase",
    "HdlStmFor",
    "HdlStmForIn",
    "HdlStmWhile",
    "HdlStmRepeat",
    "HdlStmReturn",
    "HdlStmWait",
    "HdlStmBreak",
    "HdlStmContinue",
    "HdlStmThrow",
    "HdlCompInst",
    "HdlIdDef"
]

ALL_ROOTNODETYPE_CLASSES = ALL_TYPEDEF_CLASSES+ALL_STUCTURAL_CLASSES+ALL_STATEMENT_CLASSES

ALL_EXPR_CLASSES = [
    "HdlOpType",
    "HdlOp"
]

ALL_INNERSTATEMENT_CLASSES = [
    "HdlDirection",
    "HdlTypeType",
    "HdlTypeSubtype",
    "HdlTypeAuto"
] + ALL_EXPR_CLASSES

HDL_OP_INFIXEXPREESION = [
    'MINUS_UNARY',
    'PLUS_UNARY',
    'SUB',
    'ADD',
    'DIV',
    'MUL',
    'MOD',
    'REM',
    'POW',
    'ABS',
    'AND_LOG',
    'OR_LOG',
    'AND',
    'OR',
    'NAND',
    'NOR',
    'XOR',
    'XNOR',
    'SLL',
    'SRL',
    'SLA',
    'SRA',
    'ROL',
    'ROR',
    'EQ',
    'NE',
    'IS',
    'IS_NOT',
    'LT',
    'LE',
    'GT',
    'GE',
    'EQ_MATCH',
    'NE_MATCH',
    'LT_MATCH',
    'LE_MATCH',
    'GT_MATCH',
    'GE_MATCH',
]

HDL_OP_PREFIXEXPREESION = [
    'INCR_PRE',
    'DECR_PRE',
    'INCR_POST',
    'DECR_POST',
    'NEG_LOG',
    'NEG',
    'OR_UNARY',
    'AND_UNARY',
    'NAND_UNARY',
    'NOR_UNARY',
    'XOR_UNARY',
    'XNOR_UNARY'
]


HDL_OP_POSTFIXEXPREESION = [
    'INCR_POST',
    'DECR_POST'
]

HDL_OP_MEMBERACCESSING = [
    'INDEX',
    'CONCAT',
    'REPL_CONCAT',
    'PART_SELECT_POST',
    'PART_SELECT_PRE',
    'DOT',
    'DOUBLE_COLON',
    'APOSTROPHE',
    'ARROW',
    'REFERENCE',
    'DEREFERENCE',
]

HDL_OP_ASSIGNMENT = [
    'ASSIGN',
    'PLUS_ASSIGN',
    'MINUS_ASSIGN',
    'MUL_ASSIGN',
    'DIV_ASSIGN',
    'MOD_ASSIGN',
    'AND_ASSIGN',
    'OR_ASSIGN',
    'XOR_ASSIGN',
    'SHIFT_LEFT_ASSIGN',
    'SHIFT_RIGHT_ASSIGN',
    'ARITH_SHIFT_LEFT_ASSIGN',
    'ARITH_SHIFT_RIGHT_ASSIGN',
]

HDL_OP_FUNCTIONCALL = [
    'CALL',
]

HDL_OP_OTHERS = [
    'TERNARY',
    'RISING',
    'FALLING',
    'DOWNTO',
    'TO',
    'PARAMETRIZATION',
    'MAP_ASSOCIATION',
    'RANGE',
    'THROUGHOUT',
    'DEFINE_RESOLVER',
    'TYPE_OF',
    'UNIT_SPEC'
]

ALL_CODEELEMENT_CLASSES = [
    "HdlValueId",
    "HdlAll",
    "HdlOthers",
    "HdlValueInt",
    "HdlTypeStr",
    "HdlTypeFloat"
]