util = require 'util'
concatPattern = /\s*[\s,|]+\s*/g
concatPatternAlt = /\s,\s|\s,|,\s|,/g
isTagLikePattern = /<(?![\!\/])([a-z]{1}[^>\s]*)/i
isOpeningTagLikePattern = /<(?![\!\/])([a-z]{1}[^>\s]*)/i
isClosingTagLikePattern = /<\/([a-z]{1}[^>\s]*)/i

module.exports =

    neverClose:[]
    forceInline: []
    forceBlock: []
    additionalGrammar: []
    makeNeverCLoseSelfClosing: false
    ignoreGrammar: false
    configDefaults:

        closeOnEndOfOpeningTag: false
        neverClose: 'br, hr, img, input, link, meta, area, base, col, command, embed, keygen, param, source, track, wbr'
        makeNeverCloseElementsSelfClosing: false
        forceInline: 'title, h1, h2, h3, h4, h5, h6'
        forceBlock: ''
        additionalGrammar: 'HTML'
        ignoreGrammar: false

    activate: () ->

        atom.config.observe 'autoclose-html.neverClose', callNow:true, (value) =>
            @neverClose = value.split(concatPattern)

        atom.config.observe 'autoclose-html.forceInline', callNow:true, (value) =>
            @forceInline = value.split(concatPattern)

        atom.config.observe 'autoclose-html.forceBlock', callNow:true, (value) =>
            @forceBlock = value.split(concatPattern)

        atom.config.observe 'autoclose-html.additionalGrammar', callNow:true, (value) =>
            @additionalGrammar = ['HTML'].concat(value.split(concatPatternAlt))

        atom.config.observe 'autoclose-html.makeNeverCloseElementsSelfClosing', {callNow:true}, (value) =>
            @makeNeverCLoseSelfClosing = value

        atom.config.observe 'autoclose-html.ignoreGrammar', callNow:true, (value) =>
            @ignoreGrammar = value
            atom.workspaceView.eachEditorView (editorView) =>
                editorView.trigger 'editor:grammar-changed'

        @_events()

    isInline: (eleTag) ->
        ele = document.createElement eleTag

        if eleTag.toLowerCase() in @forceBlock
            return false
        else if eleTag.toLowerCase() in @forceInline
            return true

        document.body.appendChild ele
        ret = window.getComputedStyle(ele).getPropertyValue('display') in ['inline', 'inline-block', 'none']
        document.body.appendChild ele

        ret

    isNeverClosed: (eleTag) ->
        eleTag.toLowerCase() in @neverClose

    execAutoclose: (changedEvent) ->
        if changedEvent.newText is '>'
            line = atom.workspaceView.getActiveView().editor.buffer.getLines()[changedEvent.newRange.end.row]
            partial = line.substr 0, changedEvent.newRange.start.column

            return if partial.substr(partial.length - 1, 1) is '/'

            return if not (matches = partial.substr(partial.lastIndexOf('<')).match isOpeningTagLikePattern)?

            eleTag = matches[matches.length - 1]
            if @isNeverClosed(eleTag)
                if @makeNeverCLoseSelfClosing
                    setTimeout () ->
                        tag = '/>'
                        if partial.substr partial.length - 1, 1 isnt ' '
                            tag = ' ' + tag
                        atom.workspace.activePaneItem.backspace()
                        atom.workspace.activePaneItem.insertText tag
                return

            isInline = @isInline eleTag

            setTimeout () ->
                if not isInline
                    atom.workspace.activePaneItem.insertNewline()
                    atom.workspace.activePaneItem.insertNewline()
                atom.workspace.activePaneItem.insertText('</' + eleTag + '>')
                if isInline
                    atom.workspace.activePaneItem.setCursorBufferPosition changedEvent.newRange.end
                else
                    atom.workspace.activePaneItem.autoIndentBufferRow changedEvent.newRange.end.row + 1
                    atom.workspace.activePaneItem.setCursorBufferPosition [changedEvent.newRange.end.row + 1, atom.workspace.activePaneItem.getTabText().length * atom.workspace.activePaneItem.indentationForBufferRow(changedEvent.newRange.end.row + 1)]

    _events: () ->

        fcn = (e) =>
            if e?.newText is '>'
                @execAutoclose e

        atom.workspaceView.eachEditorView (editorView) =>
            editorView.command 'editor:grammar-changed', {}, () =>
                grammar = editorView.editor.getGrammar()
                if grammar.name?.length > 0 and (@ignoreGrammar or grammar.name in @additionalGrammar)
                    editorView.editor.buffer.off 'changed', fcn
                    editorView.editor.buffer.on 'changed', fcn
                else
                    editorView.editor.buffer.off 'changed', fcn
            editorView.trigger 'editor:grammar-changed'
