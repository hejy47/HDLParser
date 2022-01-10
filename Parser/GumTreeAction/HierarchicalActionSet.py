import re
class HierarchicalActionSet():
    def __init__(self, action, parentAction, node, parent) -> None:
        self.action = action
        self.parentAction = parentAction
        self.subActions = []
        self.node = node
        self.parent = parent
        self.bugStartLineNum = 0
        self.bugEndLineNum = 0
        self.fixStartLineNum = 0
        self.fixEndLineNum = 0
    
    def __eq__(self, o: object) -> bool:
        if isinstance(o, self.__class__):
            if self.action == o.action and self.parentAction == o.parentAction and\
                self.node == o.node and self.parent == o.parent:
                return True
        return False

    def getNode(self):
        return self.node
    
    def setNode(self, node):
        self.node = node
    
    def getParent(self):
        return self.parent
    
    def setParent(self, parent):
        self.parent = parent
    
    def getAction(self):
        return self.action
    
    def setAction(self, action):
        self.action = action
    
    def getParentAction(self):
        return self.parentAction
    
    def setParentAction(self, parentAction):
        self.parentAction = parentAction
    
    def getAstNodeType(self):
        return self.node.getType().toString()
    
    def getAstNodeLabel(self):
        return self.node.getLabel().toString()

    def getSubActions(self):
        return self.subActions

    def setSubActions(self, subActions):
        self.subActions = subActions

    def addSubAction(self, action):
        self.subActions.append(action)

    def getBugStartLineNum(self):
        return self.bugStartLineNum

    def setBugStartLineNum(self, bugStartLineNum):
        self.bugStartLineNum = bugStartLineNum
    
    def getBugEndLineNum(self):
        return self.bugEndLineNum
    
    def setBugEndLineNum(self, bugEndLineNum):
        self.bugEndLineNum = bugEndLineNum

    def getFixStartLineNum(self):
        return self.fixStartLineNum

    def setFixStartLineNum(self, fixStartLineNum):
        self.fixStartLineNum = fixStartLineNum
    
    def getFixEndLineNum(self):
        return self.fixEndLineNum
    
    def setFixEndLineNum(self, fixEndLineNum):
        self.fixEndLineNum = fixEndLineNum
    
    def toString(self):
        # actStr = str(self.action)
        actType = str(self.action.getName())[:3].upper()
        actStr = ""
        if actType == "UPD":
            nodeType = str(self.node.getType())
            nodeLabel = str(self.node.getLabel())
            actStr = "{} {}@@{}".format(actType, nodeType, nodeLabel)
            if hasattr(self.action, "getValue"):
                targetLabel = str(self.action.getValue())
                actStr += " to {}".format(targetLabel)
        elif actType == "INS" or actType == "MOV":
            nodeType = str(self.node.getType())
            nodeLabel = str(self.node.getLabel())
            actStr = "{} {}@@{}".format(actType, nodeType, nodeLabel)
            if self.node.getParent():
                targetLabel = str(self.node.getParent().getLabel())
                actStr += " to {}".format(targetLabel)
            if "tree" in str(self.action.getName()):
                actStr += "\n" + re.sub(" \[.+?,.+?\]", "", str(self.node.toTreeString()))
        elif actType == "DEL":
            nodeType = str(self.node.getType())
            nodeLabel = str(self.node.getLabel())
            actStr = "{} {}@@{}".format(actType, nodeType, nodeLabel)
            if self.node.getParent():
                targetLabel = str(self.node.getParent().getLabel())
                actStr += " from {}".format(targetLabel)
            if "tree" in str(self.action.getName()):
                actStr += "\n" + re.sub(" \[.+?,.+?\]", "", str(self.node.toTreeString()))
        actStr += "\n"
        strList = [actStr]
        for actionSet in self.subActions:
            subActStr = actionSet.toString()
            strList.append("    " + subActStr[:-1].replace("\n", "\n    ") + "\n")
        
        actStr = ""
        for str1 in strList:
            actStr += str1
        return actStr
