import SwiftUI

/// 占位：华容道教学里的一课，还没做。
struct KlotskiLessonView: View {
    let course: TutorialCourse
    let lesson: TutorialLesson
    var mode: LessonMode = .lesson
    var onNextLesson: ((TutorialLesson) -> Void)? = nil

    var body: some View { Text(lesson.title) }
}
