describe "View", ->
  view = null

  describe "View objects", ->
    beforeEach ->
      Subview = class extends View
        @content: (params) ->
          @div =>
            @h2 { outlet: "header" }, params.title
            @div "I am a subview"

      TestView = class extends View
        @content: (attrs) ->
          @div keydown: 'viewClicked', class: 'rootDiv', =>
            @h1 { outlet: 'header' }, attrs.title
            @list()
            @subview 'subview', new Subview(title: "Subview")
            @div ".first1class#then-id", "w/content"
            @div "#first-id.then_class", "w/other content"
            @div "#id", "w/content", data: "and attrs"
            @div "#id", data: "w/attrs", "and content"
            @div ".B&W?", "w/content"
            @div ".treated-as#content"
            @div "#first-id#second-id", "w/content"
            @div ".1bad-identifier#-2bad-identifier", "w/content"

        @list: ->
          @ol =>
            @li outlet: 'li1', click: 'li1Clicked', class: 'foo', "one"
            @li outlet: 'li2', keypress:'li2Keypressed', class: 'bar', "two"

        initialize: (params) ->
          @initializeCalledWith = params

        foo: "bar",
        li1Clicked: ->,
        li2Keypressed: ->
        viewClicked: ->

      view = new TestView(title: "Zebra")

    describe "constructor", ->
      it "calls the content class method with the given params to produce the view's html", ->
        expect(view).toMatchSelector "div"
        expect(view.find("h1:contains(Zebra)")).toExist()
        expect(view.find("ol > li.foo:contains(one)")).toExist()
        expect(view.find("ol > li.bar:contains(two)")).toExist()

      it "calls initialize on the view with the given params", ->
        expect(view.initializeCalledWith).toEqual(title: "Zebra")

      it "wires outlet referenecs to elements with 'outlet' attributes", ->
        expect(view.li1).toMatchSelector "li.foo:contains(one)"
        expect(view.li2).toMatchSelector "li.bar:contains(two)"

      it "removes the outlet attribute from markup", ->
        expect(view.li1.attr('outlet')).toBeUndefined()
        expect(view.li2.attr('outlet')).toBeUndefined()

      it "constructs and wires outlets for subviews", ->
        expect(view.subview).toExist()
        expect(view.subview.find('h2:contains(Subview)')).toExist()
        expect(view.subview.parentView).toBe view

      it "does not overwrite outlets on the superview with outlets from the subviews", ->
        expect(view.header).toMatchSelector "h1"
        expect(view.subview.header).toMatchSelector "h2"

      it "binds events for elements with event name attributes", ->
        spyOn(view, 'viewClicked').andCallFake (event, elt) ->
          expect(event.type).toBe 'keydown'
          expect(elt).toMatchSelector "div.rootDiv"

        spyOn(view, 'li1Clicked').andCallFake (event, elt) ->
          expect(event.type).toBe 'click'
          expect(elt).toMatchSelector 'li.foo:contains(one)'

        spyOn(view, 'li2Keypressed').andCallFake (event, elt) ->
          expect(event.type).toBe 'keypress'
          expect(elt).toMatchSelector "li.bar:contains(two)"

        view.keydown()
        expect(view.viewClicked).toHaveBeenCalled()

        view.li1.click()
        expect(view.li1Clicked).toHaveBeenCalled()
        expect(view.li2Keypressed).not.toHaveBeenCalled()

        view.li1Clicked.reset()

        view.li2.keypress()
        expect(view.li2Keypressed).toHaveBeenCalled()
        expect(view.li1Clicked).not.toHaveBeenCalled()

      it "makes the view object accessible via the calling 'view' method on any child element", ->
        expect(view.view()).toBe view
        expect(view.header.view()).toBe view
        expect(view.subview.view()).toBe view.subview
        expect(view.subview.header.view()).toBe view.subview

      describe "when the first argument is a selector", ->
        it "renders an element with appropriate class and id", ->
          expect(view.find(".first1class#then-id")).toHaveText("w/content")
          expect(view.find("#first-id.then_class")).toHaveText("w/other content")

        it "renders the selector as content when it is the only argument", ->
          expect(view.find(":contains(.treated-as#content)")).toExist()

        it "only renders one id", ->
          expect(view.find("#first-id")).toExist()
          expect(view.find("#second-id")).not.toExist()

        it "doesn't render bad identifiers", ->
          expect(view.html().match(/1bad-identifier/)).toBeNull()
          expect(view.find(".1bad-identifier")).not.toExist();
          expect(view.html().match(/-2bad-identifier/)).toBeNull()
          expect(view.find("#-2bad-identifier")).not.toExist();

        it "renders attributes and content properly", ->
          expect(view.find("#id[data='and attrs']")).toHaveText("w/content")
          expect(view.find("#id[data='w/attrs']")).toHaveText("and content")

    describe "when a view is inserted within another element with jquery", ->
      [attachHandler, subviewAttachHandler] = []

      beforeEach ->
        attachHandler = jasmine.createSpy 'attachHandler'
        subviewAttachHandler = jasmine.createSpy 'subviewAttachHandler'
        view.on 'attach', attachHandler
        view.subview.on 'attach', subviewAttachHandler

      describe "when attached to an element that is on the DOM", ->
        afterEach ->
          $('#jasmine-content').empty()

        it "triggers an 'attach' event on the view and its subviews", ->
          content = $('#jasmine-content')
          content.append view
          expect(attachHandler).toHaveBeenCalled()
          expect(subviewAttachHandler).toHaveBeenCalled()

          view.detach()
          content.empty()
          attachHandler.reset()
          subviewAttachHandler.reset()

          otherElt = $('<div>')
          content.append(otherElt)
          view.insertBefore(otherElt)
          expect(attachHandler).toHaveBeenCalled()
          expect(subviewAttachHandler).toHaveBeenCalled()

      describe "when attached to an element that is not on the DOM", ->
        it "does not trigger an attach event", ->
          fragment = $('<div>')
          fragment.append view
          expect(attachHandler).not.toHaveBeenCalled()

  describe "View.render (bound to $$)", ->
    it "renders a document fragment based on tag methods called by the given function", ->
      fragment = $$ ->
        @div class: "foo", =>
          @ol =>
            @li id: 'one'
            @li id: 'two'

      expect(fragment).toMatchSelector('div.foo')
      expect(fragment.find('ol')).toExist()
      expect(fragment.find('ol li#one')).toExist()
      expect(fragment.find('ol li#two')).toExist()

    it "renders subviews", ->
      fragment = $$ ->
        @div =>
          @subview 'foo', $$ ->
            @div id: "subview"

      expect(fragment.find('div#subview')).toExist()
      expect(fragment.foo).toMatchSelector('#subview')
