using rssnews.Models;

namespace rssnews.GraphQL.InputType
{
    public class CategoryInputType : InputObjectType<Category>
    {
        protected override void Configure(IInputObjectTypeDescriptor<Category> descriptor)
        {
            descriptor.Name("CategoryInput");
            descriptor.Field(c => c.CategoryID).Type<NonNullType<IntType>>();
            descriptor.Field(c => c.CategoryName).Type<NonNullType<StringType>>();
        }
    }
}