import jpype
from BugCommit.parser import CodeNodes
from GumTreeAction.HierarchicalActionSet import HierarchicalActionSet
from utils.StartJVM import startJVM

if not jpype.isJVMStarted():startJVM()
Addition = jpype.JClass("com.github.gumtreediff.actions.model.Addition")
Delete = jpype.JClass("com.github.gumtreediff.actions.model.Delete")
Insert = jpype.JClass("com.github.gumtreediff.actions.model.Insert")
Update = jpype.JClass("com.github.gumtreediff.actions.model.Update")
Move = jpype.JClass("com.github.gumtreediff.actions.model.Move")

def regroupGumTreeResults(actions):
    actionSets = []
    updateDict = {}
    for act in actions:
        tempAct = act
        parentNode = act.getNode()
        while(str(parentNode.getType()) not in CodeNodes.ALL_ROOTNODETYPE_CLASSES or str(parentNode.getType()) == "HdlStmBlock"):
            parentNode = parentNode.getParent()
            if parentNode == None: break
            if str(parentNode.getType()) not in ["list", "tuple"]:
                parentAct = updateDict.get(parentNode, None)
                if parentAct == None:
                    parentAct = Update(parentNode, parentNode.getLabel())
                    updateDict[parentNode] = parentAct
                actSet = createActionSet(tempAct, parentAct, parentNode)
                if actSet not in actionSets: actionSets.append(actSet)
                tempAct = parentAct
        actSet = createActionSet(tempAct, None, None)
        if actSet not in actionSets: actionSets.append(actSet)

    reActionSets = []
    for actSet in actionSets:
        parentAct = actSet.getParentAction()
        if parentAct != None:
            addToActionSets(actSet, parentAct, actionSets)
        else:
            astNodeType = str(actSet.getAstNodeType())
            if astNodeType in CodeNodes.ALL_ROOTNODETYPE_CLASSES and astNodeType != "HdlStmBlock":
                reActionSets.append(actSet)
    return reActionSets

def createActionSet(act, parentAct, parent):
    actionSet = HierarchicalActionSet(act, parentAct, act.getNode(), parent)
    return actionSet

def addToActionSets(actionSet, parentAct, actionSets):
    act = actionSet.getAction()
    for actSet in actionSets:
        if actSet == actionSet: continue
        action = actSet.getAction()

        if not areRelatedActions(action, act): continue
        if action.equals(parentAct):
            actionSet.setParent(actSet)
            actSet.addSubAction(actionSet)
            sortSubActions(actSet)
            break

def findParentAction(action, actions):
    parent = action.getNode().getParent()
    if isinstance(action, Addition):
        parent = action.getParent()
    for act in actions:
        if (act.getNode() == parent):
            if (areRelatedActions(act, action)):
                return act
    return None

def areRelatedActions(parent, child):
    if isinstance(parent, Move) and not isinstance(child, Move):
        return False
    if isinstance(parent, Delete) and not isinstance(child, Delete):
        return False
    if isinstance(parent, Insert) and not isinstance(child, Addition):
        return False
    return True

def sortSubActions(actionSet):
    subActions = actionSet.getSubActions()
    # subActions.sort(key=lambda x:x.startPostion)
    actionSet.setSubActions(subActions)
