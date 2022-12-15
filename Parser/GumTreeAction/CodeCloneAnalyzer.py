import os,re
import git
import Configuration
from utils import DiffByGumTree, FileHelper
from GitHelper.GitRepository import GitRepository
from BugCommit.parser import CodeNodes

def mutateVariable(srcStr):
    srcStrList = srcStr.split("\n")
    for i in range(len(srcStrList)):
        if srcStrList[i].startswith("HdlValueId"):
            idLabel = srcStrList[i][11:]
            if idLabel not in ["reg", "wire"]:
                srcStrList[i] = "HdlValueId:hdlvalueid"
    dstStr = "\n".join(srcStrList)
    dstStr = re.sub("HdlValueInt:.+?\n", "HdlValueInt:0\n", dstStr)
    dstStr = re.sub("HdlTypeFloat:.+?\n", "HdlTypeFloat:0.0\n", dstStr)
    dstStr = re.sub("HdlTypeStr:.+?\n", "HdlTypeStr:hdltypestr\n", dstStr)
    return dstStr

def findRedundancy(srcTree, dstTree):
    srcTreeStr = str(srcTree)
    dstTreeStr = str(dstTree)
    srcTreeStr = re.sub(" \[.+?,.+?\]", "", srcTreeStr)
    dstTreeStr = re.sub(" \[.+?,.+?\]", "", dstTreeStr)
    srcTreeStr = srcTreeStr.replace(" ", "")
    dstTreeStr = dstTreeStr.replace(" ", "")
    # srcTreeStr = mutateVariable(srcTreeStr)
    # dstTreeStr = mutateVariable(dstTreeStr)
    if srcTreeStr in dstTreeStr:
        return True
    return False

def getCodeEntryRedundancyList(itemNodes, prevFile, diffArr, outputPath, scope):
    prevFilePathList = prevFile.split('/')
    prevFileName = prevFilePathList[-1][5:]
    repoName = prevFilePathList[-4]
    projectPath = os.path.join(Configuration.SUBJECTS_PATH, repoName)
    prevCommitId = prevFileName[9:17]
    prevFilePath = prevFileName[18:].replace('#', '/')
    repo = GitRepository(projectPath, "", "")
    repo.open()
    buggyFileList = repo.createFilesForRedundancy(prevCommitId, prevFilePath, os.path.join(outputPath, repoName), scope)
    # print(len(buggyFileList))
    itemRedundancy = [False for _ in itemNodes]
    prevRevisionPath = os.path.join(Configuration.REDUNDANCY_TREE_PATH, repoName, prevCommitId)
    for buggyFile in buggyFileList:
        reBuggyFileWithouSuffixName = buggyFile.replace(Configuration.REDUNDANCY_PATH, "").replace('/','#').split('.')[0]
        prevBuggyFileTreePath = os.path.join(prevRevisionPath, reBuggyFileWithouSuffixName+".txt")
        prevTreeStr = ""
        if os.path.exists(prevBuggyFileTreePath):
            with open(prevBuggyFileTreePath, 'r') as f:
                prevTreeStr = f.read()
        else:
            redundancyRepo = git.Repo(os.path.join(outputPath, repoName))
            redundancyRepo.git.checkout(prevCommitId, "--force")
            prevTree = DiffByGumTree.parse(buggyFile, diffArr)
            if prevTree == None: 
                # print("Parse Error", prevCommitId, buggyFile)
                pass
            else:
                prevTreeStr = str(prevTree.getRoot().toTreeString())
            FileHelper.creatFile(prevBuggyFileTreePath, prevTreeStr)
        if prevTreeStr == "": continue
        for index, srcItem in enumerate(itemNodes):
            if findRedundancy(srcItem, prevTreeStr):
                itemRedundancy[index] = True
        if sum(itemRedundancy) == len(itemRedundancy):
            break 
    return itemRedundancy

def getFragmentItems(itemTree, granuralarity):
    fragmentItems = []
    children = [itemTree]
    for child in children:
        childType = str(child.getType())
        if granuralarity == "Statement":
            if childType in CodeNodes.ALL_STATEMENT_CLASSES:
                fragmentItems.append(child.toTreeString())
            else:
                children.extend(child.getChildren())
        elif granuralarity == "Expression":
            if childType in CodeNodes.ALL_EXPR_CLASSES:
                fragmentItems.append(child.toTreeString())
            else:
                children.extend(child.getChildren())
    return fragmentItems

def getParentNodebyLeafNode(leafNode, granuralarity="Statement"):
    statementNode = leafNode
    statementNodeType = str(statementNode.getType())
    if granuralarity == "Statement":
        nodeTypes = CodeNodes.ALL_ROOTNODETYPE_CLASSES
        selectedNodeTypes = CodeNodes.ALL_STATEMENT_CLASSES
    elif granuralarity == "Expression":
        nodeTypes = CodeNodes.ALL_INNERSTATEMENT_CLASSES + CodeNodes.ALL_ROOTNODETYPE_CLASSES
        selectedNodeTypes = CodeNodes.ALL_EXPR_CLASSES
    while(statementNodeType not in nodeTypes):
        statementNode = statementNode.getParent()
        statementNodeType = str(statementNode.getType())
    if statementNodeType not in selectedNodeTypes:
        return ""
    try:
        return statementNode.toTreeString()
    except:
        return ""

def getFileRedundancy(diffActions, prevFile, diffArr, granuralarity="Statement", scope="Local"):
    dstNodes = []
    outputPath = os.path.join(Configuration.REDUNDANCY_PATH)
    for diffAction in diffActions:
        actionType = str(diffAction.getName())
        if actionType.startswith("insert"):
            fragmentItems = getFragmentItems(diffAction.getNode(), granuralarity)
            if len(fragmentItems) > 0:
                dstNodes.extend(fragmentItems)
            else:
                levelNode = getParentNodebyLeafNode(diffAction.getNode(), granuralarity)
                if levelNode: dstNodes.append(levelNode)
        elif actionType.startswith("update"):
            srcNode = diffAction.getNode()
            srcNodeLabel = srcNode.getLabel()
            srcNode.setLabel(diffAction.getValue())
            levelNode = getParentNodebyLeafNode(srcNode, granuralarity)
            srcNode.setLabel(srcNodeLabel)
            if levelNode: dstNodes.append(levelNode)
    codeEntryRedundancyList = getCodeEntryRedundancyList(dstNodes, prevFile, diffArr, outputPath, scope)
    codeEntryredundancyNum = sum(codeEntryRedundancyList)
    fileRedundancy = False
    if codeEntryredundancyNum == len(codeEntryRedundancyList):
        fileRedundancy = True
    return codeEntryredundancyNum, len(codeEntryRedundancyList), fileRedundancy
