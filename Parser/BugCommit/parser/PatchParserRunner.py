import os, json
import pandas as pd
from BugCommit.parser.MessageFile import MessageFile
from BugCommit.parser.PatchParser import PatchParser
from BugCommit.parser import CodeNodes
from utils import FileHelper, DiffByGumTree, Utils
import Configuration

def readMessageFiles(pathCommitsPath, dataType):
    msgFiles = {}
    projects = os.listdir(os.path.join(pathCommitsPath, dataType))
    for project in projects:
        repoMsgFiles = []
        projectPath = os.path.join(pathCommitsPath, dataType, project)
        if os.path.isdir(projectPath):
            revFilesPath = os.path.join(projectPath, "revFiles")
            prevFilesPath = os.path.join(projectPath, "prevFiles")
            diffentryFilesPath = os.path.join(projectPath, "DiffEntries")
            revFilesSubPath = os.listdir(revFilesPath)
            for revFileSubPath in revFilesSubPath:
                if os.path.isdir(os.path.join(revFilesPath, revFileSubPath)):
                    prevFileSubPath = "prev_" + revFileSubPath
                    diffentryFile = revFileSubPath + ".txt"
                    revFilePath = os.path.join(revFilesPath, revFileSubPath, revFileSubPath)
                    prevFilePath = os.path.join(prevFilesPath, prevFileSubPath, prevFileSubPath)
                    for hdlType in [".v", ".vhd", ".vhdl", ".sv"]:
                        if os.path.exists(revFilePath+hdlType) and os.path.exists(prevFilePath+hdlType):
                            revFilePath = revFilePath+hdlType
                            prevFilePath = prevFilePath+hdlType
                            break
                    msgFile = MessageFile(revFilePath, prevFilePath, os.path.join(diffentryFilesPath, diffentryFile))
                    repoMsgFiles.append(msgFile)
        msgFiles[project] = repoMsgFiles
    return msgFiles

def addToMap(dataMap, key, longSubKey):
    subKey = longSubKey.split('-')[0]
    subDataMap = dataMap.get(key, None)
    if subDataMap == None:
        subDataMap = {subKey:1}
        dataMap[key] = subDataMap
    else:
        subValue = subDataMap.get(subKey)
        if subValue == None:
            subDataMap[subKey] = 1
        else:
            subDataMap[subKey] = subValue + 1

def collectFixPatterns(fixPatterns, actionType, srcNode, targetNode):
    actionType = actionType.split('-')[0]
    subFixPatterns = fixPatterns.get(actionType, None)
    if subFixPatterns == None:
        subFixPatterns = {srcNode+"-"+targetNode:1}
        fixPatterns[actionType] = subFixPatterns
    else:
        subValue = subFixPatterns.get(srcNode+"-"+targetNode, None)
        if subValue == None:
            subFixPatterns[srcNode+"-"+targetNode] = 1
        else:
            subFixPatterns[srcNode+"-"+targetNode] = subValue + 1


def analyzePatches(allPatches, rootAstNodeMaps, innerStmtMaps, fixPatterns):
    patchesString = ""
    for hunk, patches in allPatches.items():
        patchesString += "CommitId: " + hunk.getCommitId()
        patchesString += hunk.getCommitMessage()
        patchesString += hunk.getDiffFile()[0]
        patchesString += hunk.getDiffFile()[1]
        patchesString += hunk.getDiffEntryHunkContent() + "\n"
        patchesString += "ParseResult:\n"
        for patch in patches:
            subActions = patch.getSubActions()
            deleteStmt = False
            insertStmt = False
            for subAction in subActions:
                actionStr = str(subAction.toString())
                patchesString += actionStr + "\n"

                actionType = str(subAction.getAction().getName())
                astNodeType = str(subAction.getAstNodeType())

                # actionType
                if astNodeType in CodeNodes.ALL_ROOTNODETYPE_CLASSES and astNodeType != "HdlStmBlock":
                    addToMap(rootAstNodeMaps, astNodeType, actionType)
                elif astNodeType in CodeNodes.ALL_INNERSTATEMENT_CLASSES:
                    if astNodeType == "HdlOp":
                        astNodeLabel = str(subAction.getAstNodeLabel())
                        astNodeOpType = Utils.getOpTypebyLabel(astNodeLabel)
                        astNodeType = astNodeType + "-" + astNodeOpType
                    addToMap(innerStmtMaps, astNodeType, actionType)

                    targetNode = subAction.getNode().getParent()
                    while str(targetNode.getType()) in ["list", "tuple", "HdlStmBlock"]:
                        targetNode = targetNode.getParent()
                    targetNodeType = str(targetNode.getType())
                    if targetNodeType == "HdlOp":
                        targetNodeLabel = str(targetNode.getLabel())
                        targetOpType = Utils.getOpTypebyLabel(targetNodeLabel)
                        targetNodeType = targetNodeType + "-" + targetOpType
                    collectFixPatterns(fixPatterns, actionType, astNodeType, targetNodeType)
                
                # analyzeElementsAction
                subSubActions = subAction.getSubActions()
                analyzeElementsAction(subSubActions, rootAstNodeMaps, innerStmtMaps, fixPatterns)
            patchesString += "\n"
    return patchesString

def analyzeElementsAction(actionSets, rootAstNodeMaps, innerStmtMaps, fixPatterns):
    for actionSet in actionSets:
        actionType = str(actionSet.getAction().getName())
        astNodeType = str(actionSet.getAstNodeType())
        
        # actionType
        if astNodeType in CodeNodes.ALL_ROOTNODETYPE_CLASSES and astNodeType != "HdlStmBlock":
            addToMap(rootAstNodeMaps, astNodeType, actionType)
        elif astNodeType in CodeNodes.ALL_INNERSTATEMENT_CLASSES:
            if astNodeType == "HdlOp":
                astNodeLabel = str(actionSet.getAstNodeLabel())
                astNodeOpType = Utils.getOpTypebyLabel(astNodeLabel)
                astNodeType = astNodeType + "-" + astNodeOpType
            addToMap(innerStmtMaps, astNodeType, actionType)

            targetNode = actionSet.getNode().getParent()
            while str(targetNode.getType()) in ["list", "tuple", "HdlStmBlock"]:
                targetNode = targetNode.getParent()
            targetNodeType = str(targetNode.getType())
            if targetNodeType == "HdlOp":
                targetNodeLabel = str(targetNode.getLabel())
                targetOpType = Utils.getOpTypebyLabel(targetNodeLabel)
                targetNodeType = targetNodeType + "-" + targetOpType
            collectFixPatterns(fixPatterns, actionType, astNodeType, targetNodeType)
        
        # analyzeElementsAction
        subSubActions = actionSet.getSubActions()
        analyzeElementsAction(subSubActions, rootAstNodeMaps, innerStmtMaps, fixPatterns)

def parse(repoName, msgFiles, diffArr, outputPath):
    rootAstNodeMaps = {}
    innerStmtMaps = {}
    fixPatterns = {}
    patchCommitIds = []
    allPatches = {}
    CommitRedundancyAtStatement = {}
    CommitRedundancyAtExpression = {}
    for msgFile in msgFiles:
        revFile = msgFile.getRevFile()
        prevFile = msgFile.getPrevFile()
        diffentryFile = msgFile.getDiffEntryFile()
        patchCommitId = os.path.basename(revFile)[:8]
        parser = PatchParser()

        # analyze patches
        parser.parsePatches(prevFile, revFile, diffentryFile, diffArr, Configuration.BUGGY_HUNK, Configuration.FIXED_HUNK)
        patches = parser.getPatches()
        if len(patches) > 0:
            if patchCommitId not in patchCommitIds:
                patchCommitIds.append(patchCommitId)
        allPatches.update(patches)
        
        # get redundancy at statement
        parser.parsePatchesForRedundancy(prevFile, revFile, diffArr, level="Statement")
        codeEntityRedundancyNumForLocal, codeEntitySumForLobal, fileRedundancyForLocal, codeEntityRedundancyNumForGlobal, codeEntitySumForGlobal, fileRedundancyForGlobal = parser.getRedundancy()
        if repoName not in CommitRedundancyAtStatement:
            CommitRedundancyAtStatement[repoName] = {}
        commitRedundancyList = CommitRedundancyAtStatement[repoName]
        if patchCommitId in commitRedundancyList:
            commitRedundancyList[patchCommitId]["codeEntityRedundancyNumForLocal"] += codeEntityRedundancyNumForLocal
            commitRedundancyList[patchCommitId]["codeEntitySumForLobal"] += codeEntitySumForLobal
            commitRedundancyList[patchCommitId]["commitRedundancyForLocal"] = commitRedundancyList[patchCommitId]["commitRedundancyForLocal"] and fileRedundancyForLocal
            commitRedundancyList[patchCommitId]["codeEntityRedundancyNumForGlobal"] += codeEntityRedundancyNumForGlobal
            commitRedundancyList[patchCommitId]["codeEntitySumForGlobal"] += codeEntitySumForGlobal
            commitRedundancyList[patchCommitId]["commitRedundancyForGlobal"] = commitRedundancyList[patchCommitId]["commitRedundancyForGlobal"] and fileRedundancyForGlobal
        else:
            commitRedundancyList[patchCommitId] = {}
            commitRedundancyList[patchCommitId]["codeEntityRedundancyNumForLocal"] = codeEntityRedundancyNumForLocal
            commitRedundancyList[patchCommitId]["codeEntitySumForLobal"] = codeEntitySumForLobal
            commitRedundancyList[patchCommitId]["commitRedundancyForLocal"] = fileRedundancyForLocal
            commitRedundancyList[patchCommitId]["codeEntityRedundancyNumForGlobal"] = codeEntityRedundancyNumForGlobal
            commitRedundancyList[patchCommitId]["codeEntitySumForGlobal"] = codeEntitySumForGlobal
            commitRedundancyList[patchCommitId]["commitRedundancyForGlobal"] = fileRedundancyForGlobal
        
        # get redundancy at expression
        parser.parsePatchesForRedundancy(prevFile, revFile, diffArr, level="Expression")
        codeEntityRedundancyNumForLocal, codeEntitySumForLobal, fileRedundancyForLocal, codeEntityRedundancyNumForGlobal, codeEntitySumForGlobal, fileRedundancyForGlobal = parser.getRedundancy()
        if repoName not in CommitRedundancyAtExpression:
            CommitRedundancyAtExpression[repoName] = {}
        commitRedundancyList = CommitRedundancyAtExpression[repoName]
        if patchCommitId in commitRedundancyList:
            commitRedundancyList[patchCommitId]["codeEntityRedundancyNumForLocal"] += codeEntityRedundancyNumForLocal
            commitRedundancyList[patchCommitId]["codeEntitySumForLobal"] += codeEntitySumForLobal
            commitRedundancyList[patchCommitId]["commitRedundancyForLocal"] = commitRedundancyList[patchCommitId]["commitRedundancyForLocal"] and fileRedundancyForLocal
            commitRedundancyList[patchCommitId]["codeEntityRedundancyNumForGlobal"] += codeEntityRedundancyNumForGlobal
            commitRedundancyList[patchCommitId]["codeEntitySumForGlobal"] += codeEntitySumForGlobal
            commitRedundancyList[patchCommitId]["commitRedundancyForGlobal"] = commitRedundancyList[patchCommitId]["commitRedundancyForGlobal"] and fileRedundancyForGlobal
        else:
            commitRedundancyList[patchCommitId] = {}
            commitRedundancyList[patchCommitId]["codeEntityRedundancyNumForLocal"] = codeEntityRedundancyNumForLocal
            commitRedundancyList[patchCommitId]["codeEntitySumForLobal"] = codeEntitySumForLobal
            commitRedundancyList[patchCommitId]["commitRedundancyForLocal"] = fileRedundancyForLocal
            commitRedundancyList[patchCommitId]["codeEntityRedundancyNumForGlobal"] = codeEntityRedundancyNumForGlobal
            commitRedundancyList[patchCommitId]["codeEntitySumForGlobal"] = codeEntitySumForGlobal
            commitRedundancyList[patchCommitId]["commitRedundancyForGlobal"] = fileRedundancyForGlobal

    patchesString = analyzePatches(allPatches, rootAstNodeMaps, innerStmtMaps, fixPatterns)

    CommitRedundancyAtStatementStr = json.dumps(CommitRedundancyAtStatement)
    CommitRedundancyAtStatementFileName = os.path.join(outputPath, "Patches", repoName, "CommitRedundancyAtStatement.json")
    FileHelper.creatFile(CommitRedundancyAtStatementFileName, CommitRedundancyAtStatementStr)

    CommitRedundancyAtExpressionStr = json.dumps(CommitRedundancyAtExpression)
    CommitRedundancyAtExpressionFileName = os.path.join(outputPath, "Patches", repoName, "CommitRedundancyAtExpression.json")
    FileHelper.creatFile(CommitRedundancyAtExpressionFileName, CommitRedundancyAtExpressionStr)

    outputFileName = os.path.join(outputPath, "Patches", repoName, "patchesFile.txt")
    FileHelper.creatFile(outputFileName, patchesString)
    stmtDataFrame = pd.DataFrame(rootAstNodeMaps)
    elementsDataFrame = pd.DataFrame(innerStmtMaps)
    fixPatternsDataFrame = pd.DataFrame(fixPatterns)
    outputStmtName = os.path.join(outputPath, "Patches", repoName, "stmt.csv")
    outputElementsName = os.path.join(outputPath, "Patches", repoName, "elements.csv")
    outputFixPatternsName = os.path.join(outputPath, "Patches", repoName, "fixpatterns.csv")
    FileHelper.creatCSV(outputStmtName, stmtDataFrame)
    FileHelper.creatCSV(outputElementsName, elementsDataFrame)
    FileHelper.creatCSV(outputFixPatternsName, fixPatternsDataFrame)
    
# def run(patchPath, outputPath):
#     FileHelper.deleteDirectory(Configuration.REDUNDANCY_PATH)
#     msgFiles = readMessageFiles(patchPath, "Keywords")
#     parse(msgFiles, outputPath)