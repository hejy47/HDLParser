import os
from GitHelper.GitRepository import GitRepository
from utils import FileHelper

keywords = ["bug","error","fault","fix","patch","repair"]

def collectCommits(projectsPath, outputPath, urlPath):
    projects = os.listdir(projectsPath)
    FileHelper.deleteDirectory(outputPath)
    for project in projects:
        projectPath = os.path.join(projectsPath, project)
        gitRepo = GitRepository(projectPath, revisedFilePath="", previousFilePath="")
        print("\nProject: ", project)
        gitRepo.open()
        commits = gitRepo.getAllCommits()
        print("All Commits: ", len(commits))
        keywordPatchCommits = gitRepo.filterByKeywords(commits, keywords)
        print("All collected patch-related Commits: ", len(keywordPatchCommits))

        patchCommitDiffentries = gitRepo.getCommitDiffEntries(keywordPatchCommits)
        diffEntriesPath = os.path.join(outputPath, "Keywords", project)
        commitMessagesPath = os.path.join(outputPath, "CommitMessage", project+"_Keywords.txt")
        gitRepo.createFilesForGumTree(diffEntriesPath, patchCommitDiffentries)
        gitRepo.outputCommitMessages(commitMessagesPath, keywordPatchCommits)