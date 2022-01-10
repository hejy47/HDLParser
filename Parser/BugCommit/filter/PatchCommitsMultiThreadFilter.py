import threading
import os
from BugCommit.filter import PatchCommitsFilter
from utils import DiffByGumTree

class RepoThread(threading.Thread):
    def __init__(self, repoName, outputPath, diffArr):
        threading.Thread.__init__(self)
        self.repoName = repoName
        self.outputPath = outputPath
        self.diffArr = diffArr

    def run(self) -> None:
        print("Starting ", self.repoName)
        PatchCommitsFilter.filter(self.repoName, self.outputPath, self.diffArr)
        print("Exiting ", self.repoName)

def filter(subjectsPath, outputPath):
    diffArr = DiffByGumTree.getGumTreeDiff()
    for project in os.listdir(subjectsPath):
        repoThread = RepoThread(project, outputPath, diffArr)
        repoThread.start()