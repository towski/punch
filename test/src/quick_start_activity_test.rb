activity Java::org.ruboto.example.quick_start.QuickStartActivity

setup do |activity|
  start = Time.now
end

test('initial setup') do |activity|
  loop do
    @text_view = activity.findViewById(42)
    break if @text_view || (Time.now - start > 30)
    android.util.Log.v 'PunchTest', "Loop?"
    sleep 1
  end
  assert @text_view
  assert Picture.find(1)
  #assert_equal 'What hath Matz wrought?', @text_view.text
end

test('button changes text') do |activity|
  assert Picture.find(1)
  #button = activity.findViewById(43)
  #button.performClick
  #assert_equal 'What hath Matz wrought?', @text_view.text
end
