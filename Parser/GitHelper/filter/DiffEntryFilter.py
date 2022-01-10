from git import diff


def filterHdlFile(diffentry):
    if (diffentry.b_path.endswith(".v") or diffentry.b_path.endswith(".vhd") or diffentry.b_path.endswith(".vhdl") or diffentry.b_path.endswith(".sv")):
        return True
    return False

def filterModifyType(diffentry):
    if (diffentry.change_type == "M"):
        return True
    return False

def filterAddType(diffentry):
    if (diffentry.change_type == "A"):
        return True
    return False

def filterDeleteType(diffentry):
    if (diffentry.change_type == "D"):
        return True
    return False