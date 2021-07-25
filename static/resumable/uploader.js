function getFilename(file) {
    return file.webkitRelativePath || file.fileName || file.name // Some confusion in different versions of Firefox
}

let r = undefined

function initResumableUploader(maxFiles) {
    r = new Resumable({
        target: "/api/submission-receiver-resumable",
        chunkSize: 1000 * 1000,
        simultaneousUploads: 3,
        query: {},
        generateUniqueIdentifier: function (file, event) {
            let relativePath = getFilename(file)
            let size = file.size
            let utf8 = unescape(encodeURIComponent(relativePath));
            let encoded = ""
            for (let i = 0; i < utf8.length; i++) {
                encoded += utf8.charCodeAt(i).toString()
            }

            return size + "-" + encoded
        },
        maxFiles: maxFiles,
        testChunks: true,
    })

    if (r.support) {
        document.getElementById("content-resumable").hidden = false
    } else {
        document.getElementById("content-legacy").hidden = false
    }

    r.assignBrowse(document.getElementById("resumable-drop"));
    r.assignDrop(document.getElementById("resumable-drop"));


    let progressBarsContainer = document.getElementById("progress-bars-container-resumable")

    function addFile(file) {
        let progressBar = document.createElement("progress");
        progressBar.max = 1
        progressBar.value = 0
        let progressText = document.createElement("span");
        progressText.style.fontWeight = "bold"
        progressText.style.fontSize = "90%"
        progressText.style.textShadow = "0 1px 1px rgba(0, 0, 0, 0.08)"
        progressBarsContainer.appendChild(progressText)
        progressBarsContainer.appendChild(progressBar)

        progressText.innerHTML = `${getFilename(file)}<br>Queued for upload...`

        file.progressText = progressText
        file.progressBar = progressBar
        file.uploadStartTime = null
    }

    function updateFileProgress(file) {
        if(file.uploadStartTime === null) {
            file.uploadStartTime = performance.now()
        }
        let percent_complete = file.progress() * 100

        let currentUploadSpeed = ((file.progress() * file.size) / (performance.now() - file.uploadStartTime)) * 1000 // why do i need to multiply by 1000 here?

        file.progressText.innerHTML = `${getFilename(file)}<br>Progress: ${percent_complete.toFixed(3)}% Upload speed: ${sizeToString(currentUploadSpeed)}/s`

        file.progressBar.value = file.progress()
    }

    function updateFileSuccess(file) {
        file.progressText.innerHTML = `${getFilename(file)}<br>Upload successful. Processing and validating file, please wait...`
        file.progressBar.value = 1
    }

    r.on("fileSuccess", updateFileSuccess);
    r.on("fileProgress", updateFileProgress);
    r.on("filesAdded", function (array) {
        for (let i = 0; i < array.length; i++) {
            addFile(array[i])
        }
    });
    r.on("fileRetry", function (file) {
        console.debug("fileRetry", file);
    });
    r.on("fileError", function (file, message) {
        console.debug("fileError", file, message);
    });
    r.on("uploadStart", function () {
        console.debug("upload started");
    });
    r.on("complete", function () {
        console.debug("all uploads complete");
    });
    // r.on("progress", function () {
    //     console.debug("progress");
    // });
    // r.on("error", function (message, file) {
    //     console.debug("error", message, file);
    // });
    r.on("pause", function () {
        console.debug("upload paused");
    });
    r.on("cancel", function () {
        console.debug("upload canceled");
    });
}

function startUpload() {
    r.upload()
}