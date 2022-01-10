import git
import os
import re
from GitHelper.CommitDiffEntry import CommitDiffEntry
from GitHelper.filter import DiffEntryFilter
from utils import FileHelper

class GitRepository():
    def __init__(self, repositoryPath, revisedFilePath, previousFilePath) -> None:
        self.repositoryPath = repositoryPath
        self.revisedFilePath = revisedFilePath
        self.previousFilePath = previousFilePath
        self.repo = None

    def open(self):
        self.repo = git.Repo(self.repositoryPath)

    def getAllLogs(self):
        logs = [str(i.message) for i in self.repo.iter_commits()]
        return logs

    def getAllCommits(self):
        revCommits = [i for i in self.repo.iter_commits()]
        return revCommits

    def filterByKeywords(self, commits, keywords):
        selectedCommits = []
        for commit in commits:
            for keyword in keywords:
                if keyword in str(commit.message).lower():
                    if "fix typo" in str(commit.message).lower() or "non-bug" in str(commit.message).lower() or "non-fix" in str(commit.message).lower()\
                        or "non-error" in str(commit.message).lower():
                        pass
                    else:
                        selectedCommits.append(commit)
                    break
        return selectedCommits

    def getDiffEntriesForEachCommit(self, commit):
        diffEntries = []
        parentCommits = commit.parents
        for parentCommit in parentCommits:
            diffs = commit.diff(parentCommit)
            for diff in diffs:
                gtDiffentry = CommitDiffEntry(commit, parentCommit, diff)
                diffEntries.append(gtDiffentry)
        return diffEntries

    def getCommitDiffEntries(self, commits):
        diffentries = []
        for commit in commits:
            d = self.getDiffEntriesForEachCommit(commit)
            diffentries.extend(d)
        return diffentries
    
    def createFilesForGumTree(self, outputPath, gtDiffentries):
        for gtDiffentry in gtDiffentries:
            diffentry = gtDiffentry.getDiffentry()
            if (DiffEntryFilter.filterHdlFile(diffentry) and DiffEntryFilter.filterModifyType(diffentry)):
                commit, parentCommit = gtDiffentry.getCommit(), gtDiffentry.getParentCommit()
                commitId = commit.hexsha[:8]
                fileName = diffentry.b_path.replace('/', '#')
                if ("tb" in fileName.lower() or "test" in fileName.lower()):
                    continue
                parentCommitId = parentCommit.hexsha[:8]

                fileName = self.createFileName(fileName, commitId, parentCommitId)
                fileNameWithoutSuffixName = fileName.split('.')[0]
                revisedFileContent = self.getFileContent(commit, diffentry.b_path)
                revisedFileName = os.path.join(outputPath, "revFiles", fileNameWithoutSuffixName, fileName)
                revisedIncludeFiles = re.findall("`include \"(.+?)\"", revisedFileContent)
                previousFileContent = self.getFileContent(parentCommit, diffentry.a_path)
                previousFileName = os.path.join(outputPath, "prevFiles", "prev_"+fileNameWithoutSuffixName, "prev_"+fileName)
                previousIncludeFiles = re.findall("`include \"(.+?)\"", previousFileContent)
                if (revisedFileContent == previousFileContent):
                    pass
                if (revisedFileContent != "" and previousFileContent != ""):
                    FileHelper.creatFile(revisedFileName, revisedFileContent+"\n")
                    for revisedIncludeFile in revisedIncludeFiles:
                        if '/' in revisedIncludeFile: continue
                        revisedIncludeFileContent = self.getFileContent(commit, os.path.join(os.path.dirname(diffentry.b_path), revisedIncludeFile))
                        if revisedIncludeFileContent == "": continue
                        revisedIncludeFiles.extend(re.findall("`include \"(.+?)\"", revisedIncludeFileContent))
                        revisedIncludeFileName = os.path.join(outputPath, "revFiles", fileNameWithoutSuffixName, revisedIncludeFile)
                        FileHelper.creatFile(revisedIncludeFileName, revisedIncludeFileContent+"\n")
                    FileHelper.creatFile(previousFileName, previousFileContent+"\n")
                    for previousIncludeFile in previousIncludeFiles:
                        if '/' in previousIncludeFile: continue
                        previousIncludeFileContent = self.getFileContent(parentCommit, os.path.join(os.path.dirname(diffentry.a_path), previousIncludeFile))
                        if previousIncludeFileContent == "": continue
                        previousIncludeFiles.extend(re.findall("`include \"(.+?)\"", previousIncludeFileContent))
                        previousIncludeFileName = os.path.join(outputPath, "prevFiles", "prev_"+fileNameWithoutSuffixName, previousIncludeFile)
                        FileHelper.creatFile(previousIncludeFileName, previousIncludeFileContent+"\n")
                    # output DiffEntries
                    diffentryStr = "" + commit.hexsha + "\n" + commit.summary + "\n" + \
                        self.repo.git.diff(parentCommit.hexsha+":"+diffentry.a_path, commit.hexsha+":"+diffentry.b_path)
                    diffentryPath = os.path.join(outputPath, "DiffEntries", fileNameWithoutSuffixName+".txt")
                    FileHelper.creatFile(diffentryPath, diffentryStr)
    
    def createFilesForRedundancy(self, commitId, filePath, outputPath, scope):
        revCommit = self.repo.commit(commitId)
        _, suffixName = filePath.split('.')
        prevFileList = set()
        prevRepoPath = os.path.abspath(os.path.join(outputPath))
        if not os.path.exists(prevRepoPath):
            self.repo.clone(prevRepoPath) 
        
        if scope == "Global":
            redundancyRepo = git.Repo(outputPath)
            redundancyRepo.git.checkout(commitId, "--force")
            prevFileList = FileHelper.getAllFiles(outputPath)
        elif scope == "Local":
            prevFilePath = os.path.join(outputPath, filePath)
            if self.getFileContent(revCommit, filePath) != "":
                prevFileList.add(prevFilePath)
        return list(prevFileList)

    def createFileName(self, fileName, commitId, parentCommitId):
        fileName = commitId+"_"+parentCommitId+"_"+fileName
        if(len(fileName) > 200):
            pass
        return fileName

    def getFileContent(self, commit, path):
        try:
            content = self.repo.git.show("{}:{}".format(commit.hexsha, path))
        except Exception as e:
            return ""
        else:
            return content
    
    def outputCommitMessages(self, outputFileName, commits):
        messages = ""
        for commit in commits:
            sMessage = commit.summary
            fMessage = commit.message
            messages = messages + "======Commit: " + commit.hexsha[:8] + "======\n"
            messages = messages + "======Short Message======\n"
            messages = messages + sMessage + "\n"
            messages = messages + "======Full Message======\n"
            messages = messages + fMessage + "\n"
            messages += "\n\n"
        FileHelper.creatFile(outputFileName, messages)
