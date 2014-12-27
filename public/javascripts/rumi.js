// name scope
var rumi = {};

// rumi.attachment コンストラクタ
rumi.attachment = function(url, maxsize, maxname, exceeded) {
  var obj = this;
  this.maxsize = maxsize;
  this.maxname = maxname;
  this.exceeded = exceeded;

  jQuery("body").on({
    dragover: function(e) {
      e.preventDefault();
      e.stopPropagation();
    },
    drop: function(e) {
      if (obj.exceeded) {
        alert("ファイルの利用可能容量を超過しています。");
        return false;
      }

      var files = e.originalEvent.dataTransfer.files;
      if (!obj.file_check(files)) {
        return false;
      }
      submit_file(files);
      return false;
    }
  });

  submit_file = function(files) {
    if (files.length == 0) {
      alert("ファイルではないものを添付することはできません。");
      return false;
    }

    var form_data = new FormData();
    form_data.append('authenticity_token',
                     jQuery("input[name='authenticity_token']").val());
    for (i = 0; i < files.length; i++) {
      form_data.append("files[" + i + "]", files[i]);
    }

    jQuery.ajax(url, {
      type: "POST",
      contentType: false,
      processData: false,
      data: form_data
    }).success(function(obj) {
      if (obj.status == 'OK') {
        location.href = obj.url;
      } else {
        alert(obj.message);
      }
    }).error(function(obj) {
      alert("ファイルのアップロードに失敗しました。");
    });
  }
};

// ファイルチェック
rumi.attachment.prototype.file_check = function(files) {
  var size;
  for (var i = 0; i < files.length; i++) {
    // file name length check
    if (this.bytesize(files[i].name) > this.maxname) {
      alert("ファイル名が長すぎるため保存できませんでした。");
      return false;
    }

    // file size check
    if (files[i].size == 0) {
      alert("サイズが 0 byte のファイルは添付できません。");
      return false;
    }
    size = Math.floor(files[i].size / 1024 / 1024 * 100) / 100;
    if (size > this.maxsize) {
      alert("ファイルサイズが制限を超えています。【最大" +
            this.maxsize + "MBの設定です。】【" +
            size + "MBのファイルを登録しようとしています。】");
      return false;
    }
  }

  return true;
}

// 文字列のバイト数をカウント
rumi.attachment.prototype.bytesize = function(str) {
  var encode_str = encodeURI(str);
  return encode_str.length - (encode_str.split("%").length - 1) * 2;
}

//
// rumi.dragdrop コンストラクタ
//
rumi.dragdrop = function(fileMoveAction, folderMoveAction) {
  // ファイル管理 索引ツリーフォルダーのドラッグ
  jQuery('#contentBody .sideMenu #sideList ul li a.draggable').draggable({
    opacity: 0.8,
    cursor: "move",
    helper: function(e) {
      var container = jQuery('<li />');
      container.css('border', 'none');
      container.css('background-color', '#FFFFFF');
      container.css('padding', '2px 2px 2px 2px');
      var elm_div = jQuery('<div />');
      elm_div.css('background-image', 'url(/_common/themes/gw/files/doclibrary/folder_close.gif)');
      var elm_span = jQuery('<span />').text(jQuery(this).text());
      elm_span.css('padding-left', '15px');
      elm_div.append(elm_span);
      container.append(elm_div);
      return container;
    },
    start: function(e) { },
    drag: function(e) { },
    stop: function(e) { }
  });

  // ファイル管理 ファイルのドラッグ
  jQuery('table.docformTitle tbody tr td.draggable').draggable({
    opacity: 0.8,
    cursor: "move",
    helper: function(e) {
      var container = jQuery('<td />');
      container.css('border', 'none');
      container.css('background-color', '#FFFFFF');
      container.css('padding', '2px 2px 2px 2px');
      var target = jQuery(e.currentTarget).parents('table.docformTitle tbody tr');
      jQuery('table.docformTitle tbody tr').each(function() {
        if (jQuery(this).get(0) == target.get(0) || jQuery(this).find('input').is(':checked')) {
          var elm_span = jQuery('<span />').text(jQuery(this).find('td.title a').text());
          elm_span.css('background-image', 'url(/_common/themes/gw/files/doclibrary/file.gif)');
          elm_span.css('padding-left', '15px');
          elm_span.css('display', 'block');
          elm_span.css('overflow', 'hidden');
          container.append(elm_span);
        }
      });
      return container;
    },
    start: function(e) { },
    drag: function(e) { },
    stop: function(e) { }
  });

  // ファイル管理 索引ツリーフォルダへのドロップ
  jQuery('#contentBody .sideMenu #sideList ul li a.droppable').droppable({
    hoverClass: "ui-hover",
    activeClass: "ui-active",
    tolerance: "pointer",
    greedy: true,
    drop: function(e, ui) {
      var draggable_elem_id = ui.draggable.attr('id');
      var droppable_folder = jQuery(e.target).attr('id').gsub(/^dragfolder_/, '');
      var drag_option =jQuery("input:radio[name='file_folder_option[option]']:checked").val();
      if (draggable_elem_id.search(/^dragfile_/) != -1) {
        // ファイルドラッグの場合
        var target = ui.draggable.parents('table.docformTitle tbody tr');
        var ids = '';
        jQuery('table.docformTitle tbody tr').each(function() {
          if (jQuery(this).get(0) == target.get(0) || jQuery(this).find('input').is(':checked')) {
            var elem_id = jQuery(this).find('td.draggable').attr('id');
            var uid = elem_id.gsub(/^dragfile_/, '');
            if (ids.length == 0) {
              ids = uid;
            }
            else {
              ids += ',' + uid;
            }
          }
        });
        jQuery('#file_form').append(jQuery('<input />').attr({
            type: 'hidden', name: 'drag_option', value: drag_option }));
        jQuery('#file_form').append(jQuery('<input />').attr({
            type: 'hidden', name: 'item[folder]', value: droppable_folder }));
        jQuery('#file_form').append(jQuery('<input />').attr({
            type: 'hidden', name: 'item[ids]', value: ids }));
        
        message = '';
        if (drag_option == 1) {
          message = 'ファイルをコピーしてもよろしいですか？';
        } else {
          message = 'ファイルを移動してもよろしいですか？';
        }
        if (confirm(message)) {
          var form = $('file_form');
          form.action = fileMoveAction;
          form.submit();
        }
      }
      else {
        // フォルダドラッグの場合
        var draggable_folder = draggable_elem_id.gsub(/^dragfolder_/, '');
        
        jQuery('#folder_tree_form').append(jQuery('<input />').attr({
            type: 'hidden', name: 'drag_option', value: drag_option }));
        jQuery('#folder_tree_form').append(jQuery('<input />').attr({
            type: 'hidden', name: 'item[src_folder]', value: draggable_folder }));
        jQuery('#folder_tree_form').append(jQuery('<input />').attr({
            type: 'hidden', name: 'item[dst_folder]', value: droppable_folder }));
        
        message = '';
        if (drag_option == 1) {
          message = 'フォルダをコピーしてもよろしいですか？';
        } else {
          message = 'フォルダを移動してもよろしいですか？';
        }
        if (confirm(message)) {
          var form = $('folder_tree_form');
          form.action = folderMoveAction;
          form.submit();
        }
      }
    }
  });
};

// rumi.listForm コンストラクタ
rumi.listForm = function() {
  /**
   * チェックボックス一括On/Off用メソッド
   * @param {formId} フォームID
   * @param {itemId} チェックボックスID
   * @param {value} チェックボックスをOnにするか、Offにするか
   *                Onにする場合はtrue、Offにする場合false
   */
  this.checkAll = function(formId, itemId, value) {
    var form = document.getElementById(formId);
    for (var i = 0; i < form.elements.length; i++) {
      var pattern = new RegExp('^' + itemId + '\\[.*\\]');
      if(form.elements[i].name.match(pattern)) {
        form.elements[i].checked = value;
      }
    }
    return true;
  }

  /**
   * 添付ファイル一括削除用メソッド
   * @param {formId} フォームID
   * @param {itemId} チェックボックスID
   * @param {systemName} 機能名
   * @param {titleId} タイトルID
   * @param {parentId} 添付ファイルの親ID
   */
  this.attachmentsDelete = function(formId, itemId, systemName, titleId, parentId) {
    // 削除対象の添付ファイルIDをカンマ区切りで取得
    var form = document.getElementById(formId);
    var checked_ids = '';
    for (var i = 0; i < form.elements.length; i++) {
      var pattern = new RegExp('^' + itemId + '\\[.*\\]');
      if (form.elements[i].name.match(pattern)) {
        if (form.elements[i].checked) {
          if (checked_ids.length != 0) {
            checked_ids += ',';
          }
          checked_ids += form.elements[i].value;
        }
      }
    }
    
    if (checked_ids.length == 0) {
      alert('削除する添付ファイルを選択してください。');
    }
    else {
      if (confirm('削除してよろしいですか？')) {
        // 添付ファイル一括削除用アクションを実行
        if (systemName == 'gwcircular') {
          /**  ※注意
           *   /_admin/gwcircular/:gwcircular_id/attachments/destroy_by_ids
           */
          location.href =
              '/_admin/gwcircular/' + parentId + '/attachments/destroy_by_ids' + 
              '?parent_id=' + parentId +
              '&attachment_ids=' + checked_ids;
        }
        else {
          /**  ※注意
           *   /_admin/gwcircular/:parent_id/attachments/destroy_by_ids
           */
          location.href =
              '/_admin/gwboard/' + parentId +'/attachments/destroy_by_ids' + 
              '?system=' + systemName +
              '&title_id=' + titleId +
              '&attachment_ids=' + checked_ids;
        }
        return true;
      }
    }
    return false;
  }
}

/**
 * Elementを活性／非活性にするメソッド
 * @param {Element} element
 * @param {boolean} disabled
 * @return {void}
 */
rumi.setDisabled = function(element, disabled) {
  if (disabled) {
    element.attr("disabled", "disable");
  } else {
    element.removeAttr("disabled");
  }
};

/**
 * valueがlistに存在していたらselectorにマッチするelementをdisableにするメソッド
 * @param {Array.<string|number>} list
 * @param {string|number} value
 * @param {string} selector
 * @return {void}
 */
rumi.setDisabledForIncludeList = function(list, value, selector) {
  value = Number(value);
  var disabled = false;

  list.each(function(i) {
    if (i == value) {
      disabled = true;
    }
  });

  jQuery(selector).each(function(i, element) {
    rumi.setDisabled(jQuery(element), disabled);
  });
};

// ui namespace
rumi.ui = {};

/**
 * jQuery Selectorを返却するメソッド
 * @param {string} element_id
 * @return {string}
 */
rumi.ui.idSelector = function(element_id) {
  return "#" + element_id;
};

/**
 * jQuery Selectorを返却するメソッド
 * @param {string} value
 * @return {string}
 */
rumi.ui.optionSelector = function(value) {
  return "option[value='" + value + "']";
};

/**
 * Optionを返却するメソッド
 * @param {string} name 選択肢表示名
 * @param {string} value 選択値
 * @param {string} title MouseHover時のツールチップ
 * @return {Element}
 */
rumi.ui.createOptionElement = function(name, value, title) {
  var option = jQuery("<option>").html(name).val(value);
  option.attr("title", title);

  return option;
};

/**
 * AjaxRequestメソッド
 * @param {string} ajax_url 送信先URL
 * @param {Object} ajax_data 送信データ
 * @param {Function} success_fn Ajax成功時のメソッド
 * @return {Element}
 */
rumi.ui.requestAjax = function(ajax_url, ajax_data, success_fn) {
  jQuery.ajax({
    url: ajax_url,
    data: ajax_data,
    success: success_fn,
    beforeSend: function() {
      jQuery("body").css("cursor", "wait");
    },
    complete: function() {
      jQuery("body").css("cursor", "default");
    }
  });
};

/**
 * 選択肢UIの選択肢を更新するメソッド
 * @param {JSON?} json レスポンス
 * @param {string} to_id 更新先ID
 * @return {void}
 */
rumi.ui.updateSelectOptions = function(json, to_id) {
  if (json && jQuery.isArray(json)) {
    var to = jQuery(rumi.ui.idSelector(to_id));
    to.children().remove();

    json.each(function(option) {
      to.append(rumi.ui.createOptionElement(option[2], option[1], option[0]));
    });
  }
};

/**
 * 選択肢UIの選択肢を更新するメソッド
 * @param {string} group_id 親グループID
 * @param {string} to_id 更新先ID
 * @param {boolean=} opt_with_level_no_2 階層レベル2のユーザーを表示するか
 * @return {void}
 */
rumi.ui.singleSelectGroupOnChange = function(group_id, to_id, opt_with_level_no_2) {
  var ajax_url = "/_admin/gwboard/ajaxgroups/get_users.json";
  var with_level_no_2 = opt_with_level_no_2 == true;
  var ajax_data = {
    "s_genre": group_id,
    "without_level_no_2_organization": !with_level_no_2
  };

  rumi.ui.requestAjax(ajax_url, ajax_data, function(json) {
    rumi.ui.updateSelectOptions(json, to_id);
  });
};

/**
 * グループ、ユーザー選択UIを制御するクラス
 * @param {string} uniq_id ユニークな文字列
 * @param {string} hidden_item_name フォーム送信時のitem名
 * @param {string} ajax_url ChildList取得URL
 * @param {Object} ajax_data ChildList取得Query
 * @param {number=} opt_fix_json_value JSON要素の固定値
 * @constructor
 */
rumi.ui.SelectGroup = function(uniq_id, hidden_item_name, ajax_url, ajax_data, opt_fix_json_value) {
  this.uniq_id = uniq_id;
  this.hidden_item_name = hidden_item_name;
  this.ajax_url = ajax_url;
  this.ajax_data = ajax_data;

  var ids = rumi.ui.SelectGroup.Ids;
  this.parent_list_id = rumi.ui.idSelector([ids.PREFIX, uniq_id, ids.PARENT].join("_"));
  this.selected_list_id = rumi.ui.idSelector([ids.PREFIX, uniq_id, ids.SELECTED].join("_"));
  this.child_list_id = rumi.ui.idSelector([ids.PREFIX, uniq_id, ids.CHILD].join("_"));
  this.add_btn_id = rumi.ui.idSelector([ids.PREFIX, uniq_id, ids.ADD_BTN].join("_"));
  this.remove_btn_id = rumi.ui.idSelector([ids.PREFIX, uniq_id, ids.REMOVE_BTN].join("_"));

  // 承認UIのみ利用
  this.approval_hook = false;
  this.approval_hidden_item_name_prefix = null;
  this.approval_max_count = null;
  // JSONの最初の要素における固定値
  this.fix_first_factor_json_value = opt_fix_json_value;
};

/**
 * 各UIのID
 * @enum {string}
 */
rumi.ui.SelectGroup.Ids = {
  PREFIX: "dummy",
  PARENT: "parent_list",
  CHILD: "child_list",
  SELECTED: "selected_list",
  ADD_BTN: "add_btn",
  REMOVE_BTN: "remove_btn"
};

/**
 * 部／課局を選択するUIのElementを返却する
 * @return {Element}
 */
rumi.ui.SelectGroup.prototype.getParentList = function() {
  return jQuery(this.parent_list_id);
};

/**
 * 選択済みの選択肢を格納するUIのElementを返却する
 * @return {Element}
 */
rumi.ui.SelectGroup.prototype.getSelectedList = function() {
  return jQuery(this.selected_list_id);
};

/**
 * 選択肢を格納するUIのElementを返却する
 * @return {Element}
 */
rumi.ui.SelectGroup.prototype.getChildList = function() {
  return jQuery(this.child_list_id);
};

/**
 * フォームに送信するitemのElementを返却する
 * @return {Element}
 */
rumi.ui.SelectGroup.prototype.getHiddenItem = function() {
  return jQuery(rumi.ui.idSelector(this.hidden_item_name));
};


/**
 * ApprovalHook時のフォームに送信するitemのElementを返却する
 * @return {jQuery} jQueryオブジェクト
 */
rumi.ui.SelectGroup.prototype.getApprovalHiddenItems = function() {
  return jQuery("[name^='" + this.approval_hidden_item_name_prefix + "']");
};

/**
 * 選択済みUIに選択肢を追加するメソッド
 * @return {void}
 */
rumi.ui.SelectGroup.prototype.addSelectedChild = function() {
  var fr = this.getChildList();
  var to = this.getSelectedList();

  var option = null;
  var option_selector = null;
  var values = fr.val();

  var approval_hook = this.approval_hook;
  var approval_max_count = this.approval_max_count;
  var approval_overflow = false;

  if (values && jQuery.isArray(values)) {
    values.each(function(option_id) {
      option_selector = rumi.ui.optionSelector(option_id);
      // 選択肢が存在しない場合は追加する
      if (to.find(option_selector).length == 0) {
        // 承認UIの場合は選択上限を設定する
        if (approval_hook && to.children().length >= approval_max_count) {
          approval_overflow = true;
        } else {
          option = fr.find(option_selector).first();
          to.append(rumi.ui.createOptionElement(option.text(), option_id, option.attr("title")));
        }
      }

    });

    if (approval_overflow) {
      alert("承認者の設定は5人までです");
    }
  }

  this.updateSelected();
};

/**
 * 選択済みUIから選択肢を削除するメソッド
 * @return {void}
 */
rumi.ui.SelectGroup.prototype.removeSelectedChild = function() {
  var to = this.getSelectedList();
  var values = to.val();

  if (values && jQuery.isArray(values)) {
    values.each(function(option_id) {
      to.find(rumi.ui.optionSelector(option_id)).remove();
    });
  }

  this.updateSelected();
};

/**
 * フォーム送信するitemのvalueを更新するメソッド
 * @return {void}
 */
rumi.ui.SelectGroup.prototype.updateSelected = function() {
  var arr = [];
  var to = this.getSelectedList();
  var record_name = null;
  var first_value = null;
  var fix_first_value = this.fix_first_factor_json_value;

  to.find("option").each(function(i, option) {
    option = jQuery(option);

    // "+-- グループ名" の場合は "グループ名" に変換する
    record_name = option.text();
    record_name = record_name.replace(/^\+\-*\s/, "");

    // 固定値があれば優先する
    if (fix_first_value) {
      first_value = fix_first_value;
    } else {
      first_value = option.attr("title");
    }

    arr.push([first_value, option.val(), record_name]);
  });

  if (this.approval_hook) {
    this.updateSelectedApprovalHook(arr);
  } else {
    this.getHiddenItem().val(Object.toJSON(arr));
  }

};

/**
 * 承認UIのフォーム送信時のパラメータを HookするFunction を使用するフラグをOnにするメソッド
 * @param {string} form_name フォーム名
 * @param {number} max_count 要素数
 * @return {void}
 */
rumi.ui.SelectGroup.prototype.setApprovalHook = function(hidden_item_name_prefix, max_count) {
  this.approval_hook = true;
  this.approval_hidden_item_name_prefix = hidden_item_name_prefix;
  this.approval_max_count = max_count;
};

/**
 * フォーム送信時のパラメータを HookするFunction
 * @param {Array.<title, val, name>} arr 選択済みUIの値
 * @return {void}
 */
rumi.ui.SelectGroup.prototype.updateSelectedApprovalHook = function(arr) {
  var factor = null;
  this.getApprovalHiddenItems().each(function(i, item) {
    factor = arr[i];
    item = jQuery(item);
    if (factor) {
      item.val(factor[1]);
    } else {
      item.val("");
    }
  });
};

/**
 * 選択肢UIの選択肢を更新するメソッド
 * @param {JSON?} json レスポンス
 * @return {void}
 */
rumi.ui.SelectGroup.prototype.updateChildList = function(json) {
  // replace use rumi.ui.updateSelectOptions(json, to_id);
  if (json && jQuery.isArray(json)) {
    var to = this.getChildList();
    to.children().remove();

    json.each(function(option) {
      to.append(rumi.ui.createOptionElement(option[2], option[1], option[0]));
    });
  }
};

/**
 * AjaxRequest時に渡すQueryを生成するメソッド
 * @param {string} group_id 選択された部／課局id
 * @return {Object}
 */
rumi.ui.SelectGroup.prototype.createAjaxData = function(group_id) {
  var data = {};
  jQuery.each(this.ajax_data, function(key, value) {
    if (value == "group_id") {
      value = group_id;
    }
    // group_id以外のものはそのままQueryとして格納する
    data[key] = value;
  });
  return data;
};

/**
 * 部／課局を選択UIの選択肢が変更された時に実行するメソッド
 * @param {string} group_id 選択された部／課局id
 * @return {void}
 */
rumi.ui.SelectGroup.prototype.changeParent = function(group_id) {
  var scope = this;
  rumi.ui.requestAjax(this.ajax_url, this.createAjaxData(group_id),
    function(json) {
      scope.updateChildList(json);
    });
};

/**
 * 選択済みUIの初期値設定メソッド
 * @param {JSON?} values
 * @return {void}
 */
rumi.ui.SelectGroup.prototype.initSelected = function(values) {
  if (values && jQuery.isArray(values)) {
    var to = this.getSelectedList();
    values.each(function(option) {
      to.append(rumi.ui.createOptionElement(option[2], option[1], option[0]));
    });
  }

  this.updateSelected();
};

/**
 * SelectGroupを構成する全てのUIを活性／非活性にするメソッド
 * @param {boolean} disabled
 * @return {void}
 */
rumi.ui.SelectGroup.prototype.setDisabled = function(disabled) {
  rumi.setDisabled(this.getParentList(), disabled);
  rumi.setDisabled(this.getSelectedList(), disabled);
  rumi.setDisabled(this.getChildList(), disabled);
  rumi.setDisabled(jQuery(this.add_btn_id), disabled);
  rumi.setDisabled(jQuery(this.remove_btn_id), disabled);
};

// folder_trees namespace
rumi.folder_trees = {};

/**
 * ファイル管理 フォルダツリー更新用メソッド（フォルダ「＋」「－」ボタンクリック時の処理）
 * @param {string} ajax_url Ajax用URL
 */
rumi.folder_trees.changeToggle = function(ajax_url) {
    jQuery.ajax({
      url: ajax_url,
      type: "GET"
    }).success(function(obj) {
      if (obj.status == 'OK') {
        location.href = obj.url;
      }
    }).error(function(obj) {
      alert("フォルダーツリーの表示に失敗しました。");
    });
};
