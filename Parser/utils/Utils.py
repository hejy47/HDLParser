from shutil import register_unpack_format
from BugCommit.parser import CodeNodes

def getOpTypebyLabel(label):
    if label in CodeNodes.HDL_OP_ASSIGNMENT:
        return "Assignment"
    elif label in CodeNodes.HDL_OP_INFIXEXPREESION:
        return "InfixExpression"
    elif label in CodeNodes.HDL_OP_PREFIXEXPREESION:
        return "PrefixExpression"
    elif label in CodeNodes.HDL_OP_POSTFIXEXPREESION:
        return "PostfixExpression"
    elif label in CodeNodes.HDL_OP_INFIXEXPREESION:
        return "PostfixExpression"
    elif label in CodeNodes.HDL_OP_FUNCTIONCALL:
        return "FunctionCall"
    elif label in CodeNodes.HDL_OP_MEMBERACCESSING:
        return "MemberAccessing"
    elif label in CodeNodes.HDL_OP_OTHERS:
        return label